import 'package:PiliPlus/harmony_adapt/harmony_channel.dart';
import 'package:PiliPlus/harmony_adapt/widgets/harmony_hand_dock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('two hands recenter after touch release on expanded screens', (
    tester,
  ) async {
    final previousSide = HarmonyChannel.handSide.value;
    final previousAvailability = HarmonyChannel.handAvailable.value;
    addTearDown(() {
      HarmonyChannel.handSide.value = previousSide;
      HarmonyChannel.handAvailable.value = previousAvailability;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    Future<void> hand(String side) async {
      await HarmonyChannel.handler(
        MethodCall('onHoldingHandChanged', {'side': side, 'available': true}),
      );
      await tester.pumpAndSettle();
    }

    const dock = ValueKey('hand-dock');
    for (final pixels in [2048.0, 3184.0]) {
      tester.view.physicalSize = Size(pixels, 2232);
      tester.view.devicePixelRatio = 2.875;
      final width = pixels / 2.875;
      await hand('left');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: HarmonyHandDock(
                enabled: true,
                width: width,
                builder: (_) => const ColoredBox(
                  color: Colors.black,
                  child: SizedBox(key: dock, height: 56),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(dock)).left, closeTo(0, .01));
      final touch = await tester.startGesture(
        tester.getCenter(find.byKey(dock)),
      );
      await hand('center');
      expect(
        tester.getRect(find.byKey(dock)).left,
        closeTo(0, .01),
        reason: 'changing grip must not move controls under a finger',
      );
      await touch.up();
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(dock)).center.dx,
        closeTo(width / 2, .01),
      );
      await hand('right');
      expect(tester.getRect(find.byKey(dock)).right, closeTo(width, .01));
      await hand('center');
      expect(
        tester.getRect(find.byKey(dock)).center.dx,
        closeTo(width / 2, .01),
      );
      expect(HarmonyChannel.handAvailable.value, isTrue);
      expect(tester.takeException(), isNull);
    }
  });
}
