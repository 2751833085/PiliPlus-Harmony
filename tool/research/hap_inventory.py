#!/usr/bin/env python3
"""Read HAP metadata and entry counts. Does not extract or execute package code."""
import argparse
import collections
import hashlib
import json
from pathlib import Path
import zipfile


def inventory(path):
    digest = hashlib.sha256()
    with path.open('rb') as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b''):
            digest.update(chunk)
    with zipfile.ZipFile(path) as archive:
        entries = [entry for entry in archive.infolist() if not entry.is_dir()]
        names = {entry.filename for entry in entries}
        config = {}
        if 'module.json' in names:
            info = archive.getinfo('module.json')
            if info.file_size > 2 * 1024 * 1024:
                raise ValueError('module.json exceeds the metadata limit')
            config = json.loads(archive.read(info))
        app = config.get('app', {})
        module = config.get('module', {})
        libraries = sorted(name for name in names if name.endswith('.so'))
        return {
            'file': path.name,
            'bytes': path.stat().st_size,
            'sha256': digest.hexdigest(),
            'signature_verified': False,
            'app': {key: app[key] for key in (
                'bundleName', 'versionName', 'versionCode', 'minAPIVersion',
                'targetAPIVersion', 'apiReleaseType') if key in app},
            'module': {key: module[key] for key in (
                'name', 'type', 'mainElement', 'deviceTypes') if key in module},
            'entry_count': len(entries),
            'top_level_counts': dict(sorted(collections.Counter(
                entry.filename.split('/')[0] for entry in entries).items())),
            'suffix_counts': dict(sorted(collections.Counter(
                Path(entry.filename).suffix or '(none)' for entry in entries).items())),
            'native_libraries': libraries,
            'contains_flutter_runtime': any(name.endswith('/libflutter.so') for name in libraries),
            'contains_ark_bytecode': any(name.endswith('.abc') for name in names),
            'interpretation': 'Runtime presence is a clue, not proof that every page uses that framework. This report does not recover gesture logic or source code.',
        }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('hap', type=Path)
    args = parser.parse_args()
    try:
        print(json.dumps(inventory(args.hap), ensure_ascii=False, indent=2))
    except (OSError, ValueError, zipfile.BadZipFile) as error:
        parser.exit(1, f'Cannot inspect HAP: {error}\n')


if __name__ == '__main__':
    main()
