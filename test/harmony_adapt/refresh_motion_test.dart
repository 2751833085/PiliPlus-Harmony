import 'dart:async';
import 'package:PiliPlus/common/widgets/refresh_layout.dart';
import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart'
    as refresh;
import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:PiliPlus/harmony_adapt/widgets/harmony_loading.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/memory_box.dart';

void main() {
  setUpAll(() {
    GStorage.setting = MemoryBox();
  });
  test(
    'legacy custom pull threshold is ignored',
    () async {
      await GStorage.setting.put(SettingBoxKey.refreshDragPercentage, .5);
      expect(Pref.refreshUseDefault, isTrue);
      expect(Pref.refreshDragPercentage, .25);
      await GStorage.setting.put(SettingBoxKey.refreshUseDefault, false);
      expect(Pref.refreshDragPercentage, .25);
      await GStorage.setting.put(SettingBoxKey.refreshUseDefault, true);
      expect(Pref.refreshDragPercentage, .25);
    },
  );
  for (final (width, physics) in [
    for (final width in [1008.0, 2048.0, 3184.0])
      for (final physics in const [
        ClampingScrollPhysics(),
        BouncingScrollPhysics(),
      ])
        (width, physics),
  ]) {
    testWidgets(
      'pull, release, hold, retract and repeated manual refresh at $width with $physics',
      (tester) async {
        tester.view.devicePixelRatio = 2.875;
        tester.view.physicalSize = Size(width, 2232);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final key = GlobalKey<refresh.RefreshIndicatorState>();
        var calls = 0;
        var done = Completer<void>();
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(extensions: const [HarmonyStyle()]),
            home: Scaffold(
              body: refresh.RefreshIndicator(
                key: key,
                edgeOffset: 24,
                onRefresh: () {
                  calls++;
                  return done.future;
                },
                child: ListView.builder(
                  physics: AlwaysScrollableScrollPhysics(parent: physics),
                  itemExtent: 80,
                  itemCount: 40,
                  itemBuilder: (_, index) => Text('row $index'),
                ),
              ),
            ),
          ),
        );
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(ListView)),
        );
        await gesture.moveBy(const Offset(0, 80));
        await tester.pump();
        expect(find.byType(HarmonyLoadingIndicator), findsOneWidget);
        final indicatorState = tester.state(
          find.byType(HarmonyLoadingIndicator),
        );
        expect(calls, 0);
        await gesture.moveBy(const Offset(0, 500));
        await tester.pump();
        expect(
          tester
              .renderObject<RenderRefreshLayout>(find.byType(RefreshLayout))
              .heightFactor,
          greaterThanOrEqualTo(1),
        );
        await gesture.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 180));
        await tester.pump(const Duration(milliseconds: 180));
        await tester.pump(const Duration(milliseconds: 200));
        expect(calls, 1);
        expect(tester.widget<Opacity>(find.ancestor(of: find.byType(HarmonyLoadingIndicator), matching: find.byType(Opacity)).first).opacity, 0);
        await tester.pump(const Duration(seconds: 1));
        expect(
          tester.state(find.byType(HarmonyLoadingIndicator)),
          same(indicatorState),
        );
        final indicator = tester.getCenter(
          find.byType(HarmonyLoadingIndicator),
        );
        expect(indicator.dx, closeTo(width / 2.875 / 2, 1));
        expect(
          indicator.dy,
          closeTo(24 + 26, 1),
        );
        final held = tester.getTopLeft(find.text('row 0')).dy;
        expect(held, inInclusiveRange(1, 88));
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.getTopLeft(find.text('row 0')).dy, held);
        done.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 70));
        expect(tester.getTopLeft(find.text('row 0')).dy, lessThan(held), reason: 'Content retracts smoothly after refresh.');
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pump();
        expect(find.byType(HarmonyLoadingIndicator), findsNothing);
        expect(tester.getTopLeft(find.text('row 0')).dy, closeTo(0, 1));
        done = Completer<void>();
        final manual = key.currentState!.show();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 180));
        await tester.pump(const Duration(milliseconds: 200));
        expect(calls, 2);
        expect(find.byType(HarmonyLoadingIndicator), findsOneWidget);
        done.complete();
        await tester.pump();
        await manual;
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      },
    );
  }
}
