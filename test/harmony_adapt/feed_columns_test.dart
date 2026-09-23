import 'package:PiliPlus/harmony_adapt/feed_columns.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/material.dart'
    hide SliverGridDelegateWithMaxCrossAxisExtent;
import 'package:flutter_test/flutter_test.dart';
import 'helpers/memory_box.dart';

void main() {
  setUpAll(() => GStorage.setting = MemoryBox());
  test('legacy DP values are preserved but inactive by default', () async {
    await GStorage.setting.put(SettingBoxKey.smallCardWidth, 170.0);
    expect(Pref.useCardWidthLimit, false);
    expect(Grid.smallCardWidth, 240);
    await GStorage.setting.put(SettingBoxKey.useCardWidthLimit, true);
    expect(Grid.smallCardWidth, 170);
    await GStorage.setting.put(SettingBoxKey.useCardWidthLimit, false);
    expect(Grid.smallCardWidth, 240);
    expect(Pref.smallCardWidth, 170);
  });
  testWidgets(
    'native resolution fold and rotation select explicit columns without stale grid layout',
    (tester) async {
      tester.view.devicePixelRatio = 2.875;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final (pixels, profile, columns) in [
        (const Size(1008, 2232), 0, 2),
        (const Size(2232, 1008), 1, 3),
        (const Size(2048, 2232), 2, 3),
        (const Size(2232, 2048), 3, 3),
        (const Size(2232, 3184), 4, 3),
        (const Size(3184, 2232), 5, 4),
      ]) {
        tester.view.physicalSize = pixels;
        final window = pixels / 2.875;
        expect(FeedColumns.profile(window), profile);
        for (final override in [0, 1, 2]) {
          final choices = List<int>.filled(6, 0)..[profile] = override;
          final count = FeedColumns.resolve(window, window.width, choices);
          expect(count, override == 0 ? columns : override);
          await tester.pumpWidget(
            MaterialApp(
              home: GridView.builder(
                cacheExtent: 10000,
                gridDelegate: SliverGridDelegateWithExtentAndRatio(
                  maxCrossAxisExtent: 240,
                  columns: count,
                  mainAxisExtent: 60,
                  childAspectRatio: 16 / 9,
                ),
                itemCount: 20,
                itemBuilder: (_, i) => SizedBox(key: ValueKey('card-$i')),
              ),
            ),
          );
          await tester.pump();
          expect(
            tester.getSize(find.byKey(const ValueKey('card-0'))).width,
            closeTo(window.width / count, .01),
          );
          expect(
            tester
                .getTopLeft(
                  find.byKey(ValueKey('card-$count'), skipOffstage: false),
                )
                .dy,
            greaterThan(
              tester.getTopLeft(find.byKey(const ValueKey('card-0'))).dy,
            ),
          );
          expect(tester.takeException(), isNull);
        }
      }
    },
  );
}
