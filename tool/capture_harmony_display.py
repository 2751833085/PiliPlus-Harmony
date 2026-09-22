#!/usr/bin/env python3
"""Read a connected Harmony display into a portable, identity-free test profile.

This does not change display mode, resolution, density, font settings, or locks.
Fold the device physically before recording each form. App window insets and
app-specific UI/text scaling must be measured separately; this is display data.
"""
import argparse
import datetime
import json
import re
import subprocess
from pathlib import Path


def parse_display(text):
    # The service also emits event history. Parse only current screen sections.
    section = text[text.rfind('[SCREEN PROPERTY]'):]
    display = section[section.find('[DISPLAY INFO]'):]
    def number(name, block=section):
        match = re.search(r'^' + re.escape(name) + r':\s*([\d.]+)', block, re.M)
        if not match:
            raise ValueError('Display field missing: ' + name)
        return float(match[1])
    width, height = int(number('Width', display)), int(number('Height', display))
    density = number('DensityInCurResolution')
    if min(width, height, density) <= 0:
        raise ValueError('Invalid display geometry')
    fold = re.search(r'^PhysicalFoldStatus:\s*(\S+)', text, re.M)
    ppi = re.search(r'^DPI<X, Y>:\s*([\d.]+),\s*([\d.]+)', section, re.M)
    return {
        'physical_size_px': [width, height],
        'device_pixel_ratio': density,
        'logical_size_at_ui_scale_1': [width / density, height / density],
        'density_dpi': density * 160,
        'physical_ppi': [float(ppi[1]), float(ppi[2])] if ppi else None,
        'rotation': int(number('Rotation')),
        'fold_status': fold[1] if fold else None,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--hdc', default='hdc')
    parser.add_argument('--target', help='Explicit HDC target when phone and emulator are both connected')
    parser.add_argument('--source', choices=['device', 'emulator'], default='device')
    parser.add_argument('--form', choices=['single', 'double', 'triple'], required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    def run(*argv):
        return subprocess.check_output([args.hdc, *argv], text=True, timeout=25)
    targets = [line.strip() for line in run('list', 'targets').splitlines()
               if line.strip() and not line.strip().startswith('[')]
    if args.target:
        if args.target not in targets:
            raise SystemExit('Requested HDC target is not connected')
        target = args.target
    elif len(targets) == 1:
        target = targets[0]
    else:
        raise SystemExit('Use --target when multiple devices are connected; found ' + str(len(targets)))
    profile = parse_display(run('-t', target, 'shell', 'hidumper', '-s', 'DisplayManagerService', '-a', '-a'))
    # Device-specific form names should not silently label the wrong geometry.
    # Huawei Mate XTs official display dimensions (orientation may swap axes):
    # https://consumer.huawei.com/cn/phones/mate-xts-ultimate-design/specs/
    expected = {'single': [1008, 2232], 'double': [2048, 2232], 'triple': [2232, 3184]}
    if sorted(profile['physical_size_px']) != expected[args.form]:
        raise SystemExit('Current resolution does not match the requested Mate XTS form: '
                         + str(profile['physical_size_px']))
    profile = {
        'device_model': 'DevEco TripleFold (Mate XTS geometry)' if args.source == 'emulator' else 'HUAWEI Mate XTs',
        'form': args.form,
        'captured_at': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'source': args.source + ', HDC DisplayManagerService (current fields)',
        **profile,
        'scope': 'Display metrics only. App UI/text scale and safe-area insets are not inferred.',
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(profile, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(profile, ensure_ascii=False))


if __name__ == '__main__':
    main()
