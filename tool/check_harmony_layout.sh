#!/usr/bin/env bash
# Only checks the shared layout widgets, not native plugins or the complete app.
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -n "${HARMONY_FLUTTER_HOME:-}" ]]; then
  export PATH="$HARMONY_FLUTTER_HOME/bin:$PATH"
fi
layout_test_dir="$(mktemp -d "${TMPDIR:-/tmp}/piliplus-layout.XXXXXX")"
trap 'rm -rf "$layout_test_dir"' EXIT
mkdir -p "$layout_test_dir/lib/common/widgets" "$layout_test_dir/lib/harmony_adapt" "$layout_test_dir/test/harmony_adapt"
cp lib/common/widgets/adaptive_navigation_body.dart "$layout_test_dir/lib/common/widgets/"
cp lib/harmony_adapt/window_layout.dart "$layout_test_dir/lib/harmony_adapt/"
cp test/harmony_adapt/window_layout_test.dart "$layout_test_dir/test/harmony_adapt/"
cat > "$layout_test_dir/pubspec.yaml" <<'YAML'
name: piliplus_layout_check
environment:
  sdk: '>=3.11.1 <4.0.0'
dependencies:
  flutter:
    sdk: flutter
dev_dependencies:
  flutter_test:
    sdk: flutter
YAML
cd "$layout_test_dir"
flutter test
