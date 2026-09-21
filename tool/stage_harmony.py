"""Mirror source files into an Hvigor-compatible path, preserving build caches."""
import hashlib
import json
import os
import re
import shutil
import subprocess
from pathlib import Path


def stage(source: Path, destination: Path) -> Path:
    source, destination = source.resolve(), destination.resolve()
    if not re.fullmatch(r'[A-Za-z0-9_./() @-]+', str(destination)):
        raise ValueError('HARMONY_BUILD_ROOT must use an ASCII path accepted by Hvigor.')
    if source == destination or source in destination.parents or destination in source.parents:
        raise ValueError('Build staging directory must be separate from the source tree.')
    marker = destination / '.piliplus-staging.json'
    previous = {'source': str(source), 'files': []}
    if marker.exists():
        previous = json.loads(marker.read_text())
        if previous['source'] != str(source):
            raise ValueError('Staging directory belongs to another source tree.')
    elif destination.exists() and any(destination.iterdir()):
        raise ValueError('Refusing to overwrite an unowned nonempty directory.')

    paths = subprocess.check_output(
        ['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z'], cwd=source
    ).decode().split('\0')
    files = set()
    destination.mkdir(parents=True, exist_ok=True)
    destination.chmod(0o700)
    for name in paths:
        if not name:
            continue
        original = source / name
        if not original.is_file():  # Deleted tracked files are absent from the mirror.
            continue
        target = destination / name
        if destination not in target.resolve().parents:
            raise ValueError(f'Unsafe staging path: {name}')
        target.parent.mkdir(parents=True, exist_ok=True)
        if not target.exists() or original.read_bytes() != target.read_bytes():
            shutil.copy2(original, target)
        files.add(name)
    for name in set(previous['files']) - files:
        stale = destination / name
        if destination not in stale.resolve().parents:
            raise ValueError(f'Unsafe previous staging path: {name}')
        if stale.is_file() or stale.is_symlink():
            stale.unlink()
    digest = hashlib.sha256()
    for name in sorted(files):
        digest.update(name.encode() + b'\0')
        digest.update(hashlib.sha256((destination / name).read_bytes()).digest())
    marker.write_text(json.dumps({
        'source': str(source), 'files': sorted(files), 'source_tree_sha256': digest.hexdigest()
    }) + '\n')
    return destination


if __name__ == '__main__':
    root = Path(__file__).resolve().parent.parent
    identity = hashlib.sha256(str(root).encode()).hexdigest()[:12]
    target = Path(os.environ.get('HARMONY_BUILD_ROOT', f'/tmp/piliplus-hap-build-{identity}'))
    print(stage(root, target))
