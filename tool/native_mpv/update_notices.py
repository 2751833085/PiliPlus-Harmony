#!/usr/bin/env python3
"""Collect the preserved native notices in Flutter's recognized package format."""
from pathlib import Path

package = Path(__file__).resolve().parents[2] / 'packages/media_kit_libs_ohos'
notices = ['media_kit_libs_ohos\n\n' + (package / 'LICENSE').read_text().strip()]
for path in sorted((package / 'third_party_licenses').glob('*/*')):
    if path.is_file() and path.suffix != '.html':
        notices.append(f'{path.parent.name} ({path.name})\n\n' + path.read_text().strip())
(package / 'NOTICES').write_text(('\n' + '-' * 80 + '\n').join(notices) + '\n')
print(f'Collected {len(notices)} license notices for Flutter packaging.')
