import 'package:PiliPlus/plugin/pl_player/widgets/app_bar_ani.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final fadeOnly in [true, false]) {
    testWidgets('mode buttons require a fully shown bar (fade=$fadeOnly)', (
      tester,
    ) async {
      final controller = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 200),
      );
      addTearDown(controller.dispose);
      var switches = 0;
      var videoTaps = 0;
      const button = ValueKey('mode-button');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                height: 240,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => videoTaps++,
                      ),
                    ),
                    Positioned(
                      top: 80,
                      left: 80,
                      width: 200,
                      height: 40,
                      child: AppBarAni(
                        controller: controller,
                        isTop: false,
                        isFullScreen: false,
                        removeSafeArea: true,
                        fadeOnly: fadeOnly,
                        child: TextButton(
                          key: button,
                          onPressed: () => switches++,
                          child: const Text('竖屏短视频'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      Future<void> tap() => tester.tapAt(tester.getCenter(find.byKey(button)));
      await tap();
      expect(switches, 0);
      expect(videoTaps, 1);
      controller.forward();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tap();
      expect(switches, 0, reason: 'revealing controls is not a mode selection');
      expect(videoTaps, 2);
      await tester.pumpAndSettle();
      await tap();
      expect(
        switches,
        1,
        reason: 'a deliberate tap still switches immediately',
      );
      controller.reverse();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tap();
      expect(
        switches,
        1,
        reason: 'fading/moving controls must not intercept taps',
      );
      expect(videoTaps, 3);
      await tester.pumpAndSettle();
      await tap();
      expect(switches, 1);
      expect(videoTaps, 4);
      expect(tester.takeException(), isNull);
    });
  }
}
