import 'package:PiliPlus/harmony_adapt/widgets/harmony_loading.dart';
import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart'
    as refresh;
import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:PiliPlus/models/common/harmony_refresh_sensitivity.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/memory_box.dart';

void main() {
  setUpAll(() => GStorage.setting = MemoryBox());
  for (final physics in const [
    BouncingScrollPhysics(),
    ClampingScrollPhysics(),
  ]) {
    testWidgets(
      'normal scrolling and accidental pulls do not refresh but a light release does with $physics',
      (tester) async {
        var calls = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(extensions: const [HarmonyStyle()]),
            home: Scaffold(
              body: refresh.RefreshIndicator(
                onRefresh: () async {
                  calls++;
                },
                child: ListView(
                  physics: AlwaysScrollableScrollPhysics(parent: physics),
                  children: const [
                    SizedBox(height: 80, child: Text('first')),
                    SizedBox(height: 1200),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.drag(find.byType(ListView), const Offset(0, -120));
        await tester.pumpAndSettle();
        expect(calls, 0);
        expect(find.byType(HarmonyLoadingIndicator), findsNothing);
        await tester.drag(find.byType(ListView), const Offset(0, 100));
        await tester.pumpAndSettle();
        expect(calls, 0);
        expect(find.byType(HarmonyLoadingIndicator), findsNothing);
        tester
            .state<ScrollableState>(find.byType(Scrollable))
            .position
            .jumpTo(0);
        await tester.pump();
        final before = tester.getTopLeft(find.text('first')).dy;
        final gesture = await tester.startGesture(const Offset(150, 160));
        await gesture.moveBy(const Offset(0, 20));
        await tester.pump();
        await gesture.moveBy(const Offset(0, 10));
        await tester.pump();
        expect(calls, 0);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(calls, 0);
        expect(tester.getTopLeft(find.text('first')).dy, closeTo(before, 1));

        final light = await tester.startGesture(const Offset(150, 160));
        await light.moveBy(const Offset(0, 66));
        await tester.pump();
        expect(
          tester
              .getSize(find.byKey(const ValueKey('harmony-refresh-reveal')))
              .height,
          inExclusiveRange(56, 64),
        );
        expect(calls, 0);
        await light.up();
        await tester.pumpAndSettle();
        expect(calls, 1);
        expect(tester.getTopLeft(find.text('first')).dy, closeTo(before, 1));

        const key = SettingBoxKey.harmonyRefreshSensitivity;
        addTearDown(() => GStorage.setting.delete(key));
        await GStorage.setting.put(
          key,
          HarmonyRefreshSensitivity.standard.name,
        );
        final blocked = await tester.startGesture(const Offset(150, 160));
        await blocked.moveBy(const Offset(0, 66));
        await blocked.up();
        await tester.pumpAndSettle();
        expect(calls, 1, reason: 'The next drag uses the saved standard level');
        final standard = await tester.startGesture(const Offset(150, 160));
        await standard.moveBy(const Offset(0, 90));
        await standard.up();
        await tester.pumpAndSettle();
        expect(calls, 2);
      },
    );
  }
}
