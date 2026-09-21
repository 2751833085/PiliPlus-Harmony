#!/usr/bin/env python3
"""Build the vendored ARM64 OHOS libmpv from pinned sources (macOS host)."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile

ROOT = Path(__file__).resolve().parents[1]
META = ROOT / 'tool/native_mpv/sources.json'
PACKAGE = ROOT / 'packages/media_kit_libs_ohos'
COMPONENTS = ('libxml2 mbedtls dav1d libwebp ffmpeg fribidi freetype harfbuzz '
              'fontconfig libass dovi_tools lcms shaderc libplacebo lua mpv').split()


def run(*args, cwd=None, env=None):
    subprocess.run(args, cwd=cwd, env=env, check=True)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def clone(spec, path):
    run('git', 'init', str(path))
    run('git', 'remote', 'add', 'origin', spec['url'], cwd=path)
    run('git', 'fetch', '--depth=1', 'origin', spec['commit'], cwd=path)
    run('git', 'checkout', '--detach', 'FETCH_HEAD', cwd=path)
    run('git', 'submodule', 'update', '--init', '--recursive', '--depth=1', cwd=path)


def crossfile(ndk, compiler):
    values = {'c': 'clang', 'cpp': 'clang++', 'ar': 'llvm-ar',
              'strip': 'llvm-strip', 'c_ld': 'ld.lld', 'cpp_ld': 'ld.lld'}
    text = "[host_machine]\nsystem = 'linux'\ncpu_family = 'aarch64'\ncpu = 'arm64-v8a'\nendian = 'little'\n\n[binaries]\n"
    for key, value in values.items():
        text += f'{key} = {str(compiler / "bin" / value)!r}\n'
    text += "pkg-config = 'pkg-config'\n\n[built-in options]\n"
    target = ['--target=aarch64-linux-ohos', f'--sysroot={ndk}/native/sysroot']
    for key in ('c_args', 'cpp_args'):
        text += f"{key} = {target + ['-fPIC', '-D__MUSL__=1', '-Wno-int-conversion']!r}\n"
    for key in ('c_link_args', 'cpp_link_args'):
        text += f"{key} = {target + ['-fuse-ld=lld', '-lc++_shared']!r}\n"
    return text + "buildtype = 'release'\ndefault_library = 'static'\nwrap_mode = 'nodownload'\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='Only verify vendored binary/hash; no network or build')
    parser.add_argument('--work-dir', type=Path, default=Path('/tmp/piliplus-mpv-rebuild'))
    parser.add_argument('--ndk', type=Path, default=os.environ.get('OHOS_NDK_HOME'))
    parser.add_argument('--host-sdk', type=Path, default=os.environ.get('SDKROOT'))
    parser.add_argument('--jobs', type=int, default=8)
    parser.add_argument('--install', action='store_true', help='Copy the resulting library and update its hashes in the checkout')
    args = parser.parse_args()
    data = json.loads(META.read_text())
    library = PACKAGE / 'ohos/libs/arm64-v8a/libmpv.so'
    if args.check:
        digest = sha(library)
        expected = (PACKAGE / 'ohos/src/main/cpp/libmpv.sha256').read_text().strip()
        if digest != expected or digest != data['library']['sha256']:
            raise SystemExit('Vendored libmpv hash mismatch')
        print(f'ARM64 libmpv verified: {digest}')
        return
    if sys.platform != 'darwin':
        raise SystemExit('This driver was validated on macOS; Linux needs a host toolchain adaptation.')
    if not args.ndk or not (args.ndk / 'native/sysroot').is_dir():
        raise SystemExit('Pass --ndk pointing to SDK 26 openharmony, or set OHOS_NDK_HOME.')
    ndk = args.ndk.resolve()
    if any(c.isspace() for c in str(ndk)):
        raise SystemExit('Upstream scripts require an SDK path without whitespace.')
    if args.jobs < 1: raise SystemExit('--jobs must be positive')
    for program in ('git', 'curl', 'meson', 'ninja', 'pkg-config', 'make', 'rustup', 'cargo'):
        if not shutil.which(program): raise SystemExit(f'Missing tool: {program}')
    run('cargo', 'cinstall', '--version')
    work = args.work_dir.resolve()
    if any(c.isspace() for c in str(work)):
        raise SystemExit('Choose a build path without whitespace.')
    # A fresh directory avoids silently resetting or cleaning someone else\'s work.
    if work.exists() and any(work.iterdir()):
        raise SystemExit(f'Choose an empty --work-dir; refusing to overwrite {work}')
    work.mkdir(parents=True, exist_ok=True)
    clone(data['builder'], work)
    deps = work / 'libmpv'
    deps.mkdir()
    for name, spec in data['dependencies'].items(): clone(spec, deps / name)
    for name, spec in data['archives'].items():
        archive = deps / f'{name}.source.tar'
        run('curl', '--fail', '--location', '--retry', '3', spec['url'], '-o', str(archive))
        if sha(archive) != spec['sha256']: raise SystemExit(f'Source hash mismatch: {name}')
        with tarfile.open(archive) as tar:
            # Preserve archive top-level while applying Python\'s safe extraction filter.
            tar.extractall(deps / f'{name}.unpack', filter='data')
        children = list((deps / f'{name}.unpack').iterdir())
        if len(children) != 1 or not children[0].is_dir(): raise SystemExit(f'Unexpected archive layout: {name}')
        children[0].rename(deps / name)
    run(sys.executable, 'utils/git-sync-deps', cwd=deps / 'shaderc')
    run('git', 'apply', str(ROOT / 'tool/native_mpv/full-audio.patch'), cwd=work)
    # Required source patches must apply; never silently skip a failed AV3A patch.
    for patch in sorted((work / 'patches').glob('*/*')):
        if patch.is_file(): run('git', 'apply', str(patch), cwd=deps / patch.parent.name)
    envfile = work / 'env.sh'
    value = envfile.read_text()
    lines = []
    for line in value.splitlines():
        if line.strip().startswith('export OHOS_NDK_HOME='):
            line = '  export OHOS_NDK_HOME=${OHOS_NDK_HOME:?Set OHOS_NDK_HOME}'
        elif line.strip().startswith('export CORES='):
            line = '  export CORES=${PILIPLUS_BUILD_JOBS:-8}'
        lines.append(line)
    envfile.write_text('\n'.join(lines) + '\n')
    compiler = ndk.parent / 'hms/native/BiSheng'
    if not compiler.is_dir(): raise SystemExit('This build requires the SDK 26 BiSheng compiler.')
    (work / 'crossfiles/arm64-crossfile-macos.ini').write_text(crossfile(ndk, compiler))
    env = os.environ.copy()
    env.update(OHOS_NDK_HOME=str(ndk), PILIPLUS_BUILD_JOBS=str(args.jobs), CARGO_BUILD_JOBS=str(args.jobs))
    if args.host_sdk: env['SDKROOT'] = str(args.host_sdk.resolve())
    for component in COMPONENTS: run('bash', f'scripts/{component}.sh', 'build', cwd=work, env=env)
    config = (deps / 'ffmpeg/.build/config_components.h').read_text()
    for flag in ('LOUDNORM_FILTER', 'DYNAUDNORM_FILTER', 'AV3A_OH_DECODER', 'AV3A_PARSER'):
        if f'#define CONFIG_{flag} 1' not in config: raise SystemExit(f'Required feature missing: {flag}')
    built = deps / 'arm64-build/libmpv.so'
    unstripped_digest = sha(built)
    run(str(ndk / 'native/llvm/bin/llvm-strip'), '--strip-all', str(built))
    print(f'Built {built}\nSHA256 {sha(built)}')
    if args.install:
        shutil.copy2(built, library)
        data['library'] = {'sha256': sha(built), 'bytes': built.stat().st_size,
                           'unstripped_sha256': unstripped_digest}
        META.write_text(json.dumps(data, indent=2, ensure_ascii=False) + '\n')
        (PACKAGE / 'ohos/src/main/cpp/libmpv.sha256').write_text(sha(built) + '\n')
        print('Updated vendored library and hashes. Rebuild/test the HAP before distribution.')


if __name__ == '__main__':
    main()
