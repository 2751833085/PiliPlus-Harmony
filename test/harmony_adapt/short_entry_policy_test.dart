import 'package:PiliPlus/pages/video/shorts/entry_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'only portrait content enters by default; unknown dimensions resolve once',
    () {
      for (final enabled in [false, true]) {
        for (final supported in [false, true]) {
          final portrait = ShortVideoEntryPolicy(
            enabled: enabled,
            supported: supported,
            portraitHint: true,
          );
          expect(portrait.initialMode, enabled && supported);
          final unknown = ShortVideoEntryPolicy(
            enabled: enabled,
            supported: supported,
            portraitHint: false,
          );
          expect(unknown.initialMode, false);
          expect(unknown.resolve(true), enabled && supported);
          expect(unknown.resolve(true), isNull);
        }
      }
      final landscape = ShortVideoEntryPolicy(
        enabled: true,
        supported: true,
        portraitHint: false,
      );
      expect(landscape.resolve(false), false);
      // A later playlist item does not unexpectedly change an ordinary page.
      expect(landscape.resolve(true), isNull);
    },
  );
  test(
    'returning to details is not undone by late dimensions or feed items',
    () {
      final entry = ShortVideoEntryPolicy(
        enabled: true,
        supported: true,
        portraitHint: false,
      );
      entry.manualSelection();
      expect(entry.resolve(true), isNull);
      final feed = ShortVideoEntryPolicy(
        enabled: true,
        supported: true,
        portraitHint: true,
      );
      expect(feed.initialMode, true);
      expect(feed.resolve(false), false);
      expect(feed.resolve(true), isNull);
    },
  );
}
