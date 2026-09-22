#!/usr/bin/env bash
# Run from any directory. HARMONY_FLUTTER_HOME must refer to the OHOS fork.
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -f .harmony-env.local ]]; then source .harmony-env.local; fi

if [[ -n "${HARMONY_FLUTTER_HOME:-}" ]]; then
  export PATH="$HARMONY_FLUTTER_HOME/bin:$PATH"
fi
deveco_home="${DEVECO_HOME:-/Applications/DevEco-Studio.app/Contents}"
if [[ -n "${HARMONY_COMMAND_LINE_TOOLS_HOME:-}" ]]; then
  export DEVECO_SDK_HOME="${DEVECO_SDK_HOME:-$HARMONY_COMMAND_LINE_TOOLS_HOME/sdk}"
  export PATH="$HARMONY_COMMAND_LINE_TOOLS_HOME/tool/node/bin:$HARMONY_COMMAND_LINE_TOOLS_HOME/bin:$PATH"
elif [[ -d "$deveco_home" ]]; then
  export DEVECO_SDK_HOME="${DEVECO_SDK_HOME:-${HOS_SDK_HOME:-$deveco_home/sdk}}"
  export PATH="$deveco_home/tools/node/bin:$deveco_home/tools/ohpm/bin:$deveco_home/tools/hvigor/bin:$PATH"
fi
if [[ -z "${JAVA_HOME:-}" && -d "$deveco_home/jbr/Contents/Home" ]]; then
  export JAVA_HOME="$deveco_home/jbr/Contents/Home"
fi
if [[ -n "${JAVA_HOME:-}" ]]; then
  export PATH="$JAVA_HOME/bin:$PATH"
fi

mode="${1:-doctor}"
case "$mode" in
  doctor|debug|release) ;;
  *) echo 'Usage: bash tool/harmony.sh [doctor|debug|release]' >&2; exit 2 ;;
esac

python3 tool/rebuild_harmony_mpv.py --check

missing=0
for command in flutter dart node ohpm hvigorw java python3 git git-lfs; do
  if command -v "$command" >/dev/null; then
    printf 'OK      %s: %s\n' "$command" "$(command -v "$command")"
  else
    printf 'MISSING %s\n' "$command"
    missing=1
  fi
done
sdk_home="${DEVECO_SDK_HOME:-${HOS_SDK_HOME:-}}"
if [[ -z "$sdk_home" || ! -d "$sdk_home" ]]; then
  echo 'MISSING HarmonyOS SDK: set DEVECO_SDK_HOME or HOS_SDK_HOME.'
  missing=1
else
  printf 'OK      SDK directory: %s\n' "$sdk_home"
  if ! python3 tool/check_harmony_sdk.py "$sdk_home"; then missing=1; fi
fi

if [[ "$mode" == doctor ]]; then
  if command -v flutter >/dev/null; then flutter doctor -v; fi
  exit "$missing"
fi
if (( missing )); then
  echo 'Build blocked: install the missing tools. See docs/harmony/README.md.' >&2
  exit 1
fi
if ! flutter build hap --help >/dev/null 2>&1; then
  echo 'This Flutter SDK does not support HAP. Use CPF-Flutter oh-3.44.9-dev.' >&2
  exit 1
fi

export HARMONY_SOURCE_ROOT="$PWD"
# Hvigor rejects Chinese characters and '~' in project paths. Keep the user's
# checkout in place; mirror only source files, never .git or dependency caches.
build_root="$(python3 tool/stage_harmony.py)"
printf 'Building source from %s in %s\n' "$HARMONY_SOURCE_ROOT" "$build_root"
cd "$build_root"
if [[ -f "$HARMONY_SOURCE_ROOT/ohos/build-profile.local.json5" ]]; then
  cp "$HARMONY_SOURCE_ROOT/ohos/build-profile.local.json5" ohos/build-profile.json5
  chmod 600 ohos/build-profile.json5
  python3 tool/check_harmony_sdk.py "$sdk_home"
fi

flutter pub get
flutter test test/harmony_adapt
mkdir -p build/harmony
python3 - <<'PY'
import json, os, re, subprocess
from pathlib import Path

def git(*args):
    return subprocess.check_output(['git', *args], cwd=os.environ['HARMONY_SOURCE_ROOT'], text=True).strip()

version = re.search(r'^version:\s*(\S+)', Path('pubspec.yaml').read_text(), re.M)[1]
data = {
    'pili.name': version.split('+')[0] + '-ohos',
    'pili.hash': git('rev-parse', 'HEAD'),
    'pili.code': int(version.split('+')[1]),
    'pili.time': int(git('show', '-s', '--format=%ct', 'HEAD')),
    'ENABLE_FLEX_OVERFLOW': False,
    'HARMONY_LAYOUT_DIAGNOSTICS': os.environ.get('HARMONY_LAYOUT_DIAGNOSTICS') == '1',
}
Path('build/harmony/env.json').write_text(json.dumps(data) + '\n')
PY
signing_flag=--no-codesign
if [[ "${HARMONY_CODESIGN:-0}" == 1 ]]; then signing_flag=--codesign; fi
flutter build hap "--$mode" "$signing_flag" --dart-define-from-file=build/harmony/env.json
HARMONY_BUILD_MODE="$mode" HARMONY_SIGNED="${HARMONY_CODESIGN:-0}" python3 - <<'PY'
import hashlib, json, os, shutil, subprocess, zipfile
from pathlib import Path
suffix = '*-signed.hap' if os.environ['HARMONY_SIGNED'] == '1' else '*-unsigned.hap'
paths = list(Path('ohos/entry/build').rglob(suffix))
if not paths:
    raise SystemExit('Build returned without producing a HAP.')
output = Path(os.environ['HARMONY_SOURCE_ROOT']) / 'build/harmony' / os.environ['HARMONY_BUILD_MODE']
output.mkdir(parents=True, exist_ok=True)
for path in paths:
    with zipfile.ZipFile(path) as archive:
        bad = archive.testzip()
        if bad: raise SystemExit(f'HAP CRC failed: {bad}')
        module = json.loads(archive.read('module.json'))
        expected = {'ets/modules.abc', 'libs/arm64-v8a/libflutter.so', 'libs/arm64-v8a/libmpv.so'}
        if os.environ['HARMONY_BUILD_MODE'] == 'release': expected.add('libs/arm64-v8a/libapp.so')
        missing = expected - set(archive.namelist())
        if missing: raise SystemExit(f'HAP is incomplete: {missing}')
        native = json.loads(Path('tool/native_mpv/sources.json').read_text())
        mpv_digest = hashlib.sha256(archive.read('libs/arm64-v8a/libmpv.so')).hexdigest()
        if mpv_digest != native['library']['sha256']:
            raise SystemExit('HAP contains an unexpected libmpv; refusing to export it.')
    target = output / path.relative_to('ohos/entry/build')
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(path, target)
    digest = hashlib.sha256(target.read_bytes()).hexdigest()
    target.with_suffix('.hap.sha256').write_text(f'{digest}  {target.name}\n')
    source = Path(os.environ['HARMONY_SOURCE_ROOT'])
    stage = json.loads(Path('.piliplus-staging.json').read_text())
    manifest = {
        'hap': target.name, 'sha256': digest, 'bytes': target.stat().st_size,
        'mode': os.environ['HARMONY_BUILD_MODE'], 'signed': os.environ['HARMONY_SIGNED'] == '1',
        'base_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=source, text=True).strip(),
        'source_tree_sha256': stage['source_tree_sha256'],
        'toolchain': json.loads((source / 'docs/harmony/toolchain.json').read_text()),
        'app': module['app'], 'device_types': module['module']['deviceTypes'],
        'libmpv_sha256': mpv_digest,
        'layout_diagnostics': os.environ.get('HARMONY_LAYOUT_DIAGNOSTICS') == '1',
    }
    target.with_suffix('.build.json').write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + '\n')
    print(f'{target}\nSHA256 {digest}')
if os.environ['HARMONY_SIGNED'] != '1':
    print('Unsigned HAPs require development signing before installation on a phone.')
PY
