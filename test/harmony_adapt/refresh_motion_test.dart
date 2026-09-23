import 'dart:async';
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
  setUpAll(() => GStorage.setting = MemoryBox());
  test('legacy custom pull threshold is ignored', () async {
    await GStorage.setting.put(SettingBoxKey.refreshDragPercentage, .5);
    await GStorage.setting.put(SettingBoxKey.refreshUseDefault, false);
    expect(Pref.refreshDragPercentage, .25);
  });
  for (final width in [1008.0, 2048.0, 3184.0]) {
    for (final physics in const [
      ClampingScrollPhysics(),
      BouncingScrollPhysics(),
    ]) {
      testWidgets(
        'refresh requires release and shows one bottom loader at $width with $physics',
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
          final top = tester.getTopLeft(find.text('row 0')).dy;
          final gesture = await tester.startGesture(
            tester.getCenter(find.byType(ListView)),
          );
          await gesture.moveBy(const Offset(0, 80));
          await tester.pump();
          expect(find.byType(HarmonyLoadingIndicator), findsNothing);
          await gesture.moveBy(const Offset(0, 500));
          await tester.pump();
          await tester.pump(const Duration(seconds: 2));
          expect(
            calls,
            0,
            reason: 'Holding a long pull never starts a request.',
          );
          expect(find.byType(HarmonyLoadingIndicator), findsNothing);
          expect(tester.getTopLeft(find.text('row 0')).dy, closeTo(top, 1));
          await gesture.up();
          await tester.pump();
          expect(calls, 1);
          expect(find.byType(HarmonyLoadingIndicator), findsOneWidget);
          expect(
            tester.getCenter(find.byType(HarmonyLoadingIndicator)).dy,
            greaterThan(500),
          );
          await tester.pump(const Duration(seconds: 1));
          expect(tester.getTopLeft(find.text('row 0')).dy, closeTo(top, 1));
          done.complete();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          final fade = tester.widget<Opacity>(
            find
                .ancestor(
                  of: find.byType(HarmonyLoadingIndicator),
                  matching: find.byType(Opacity),
                )
                .first,
          );
          expect(fade.opacity, inExclusiveRange(0, 1));
          await tester.pumpAndSettle();
          expect(find.byType(HarmonyLoadingIndicator), findsNothing);
          expect(tester.getTopLeft(find.text('row 0')).dy, closeTo(top, 1));
          done = Completer<void>();
          final manual = key.currentState!.show();
          await tester.pump();
          expect(calls, 2);
          expect(find.byType(HarmonyLoadingIndicator), findsOneWidget);
          done.complete();
          await manual;
          await tester.pumpAndSettle();
          expect(find.byType(HarmonyLoadingIndicator), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
