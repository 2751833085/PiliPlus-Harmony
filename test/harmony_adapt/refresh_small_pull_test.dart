import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart'
    as refresh;
import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:PiliPlus/utils/storage.dart';
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
      'small pull follows content but does not refresh with $physics',
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
        final before = tester.getTopLeft(find.text('first')).dy;
        final gesture = await tester.startGesture(const Offset(150, 160));
        await gesture.moveBy(const Offset(0, 35));
        await tester.pump();
        await gesture.moveBy(const Offset(0, 20));
        await tester.pump();
        expect(tester.getTopLeft(find.text('first')).dy, greaterThan(before));
        expect(calls, 0);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(calls, 0);
        expect(tester.getTopLeft(find.text('first')).dy, closeTo(before, 1));
      },
    );
  }
}
