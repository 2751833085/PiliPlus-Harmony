"""Check installed API level against the project's target before downloading dependencies."""
import json
import re
import sys
from pathlib import Path


def api_level(version):
    # Older SDK versions use e.g. 6.0.2(22); new SDKs use e.g. 26.0.0.
    match = re.search(r'\((\d+)\)', str(version))
    return int(match[1] if match else str(version).split('.')[0])


def main():
    sdk = Path(sys.argv[1])
    profile = Path(__file__).resolve().parent.parent / 'ohos/build-profile.json5'
    target = re.search(r'targetSdkVersion["\']?\s*:\s*["\']([^"\']+)', profile.read_text())[1]
    required = api_level(target)
    installed = []
    for manifest in sdk.glob('*/sdk-pkg.json'):
        data = json.loads(manifest.read_text())['data']
        installed.append(api_level(data['apiVersion']))
    if required not in installed:
        print(f'MISMATCH target API {required}; installed APIs: {installed or "none"}.')
        print('Install the matching SDK. Do not lower targetSdkVersion without adapting native APIs.')
        return 1
    print(f'OK      target SDK API {required}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
