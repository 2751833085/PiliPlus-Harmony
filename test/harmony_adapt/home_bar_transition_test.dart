import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/harmony_adapt/shell_bars_observer.dart';
import 'package:PiliPlus/harmony_adapt/harmony_motion.dart';

void main() {
  test('interactive coverage follows the finger exactly', () {
    expect(HarmonyMotion.pageCoverage(.3, interactive: true), .3);
    expect(HarmonyMotion.pageCoverage(0, interactive: false), 0);
    expect(HarmonyMotion.pageCoverage(1, interactive: false), 1);
  });
  testWidgets(
    'native home header remains clipped until the returning page leaves',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.values.firstWhere(
        (p) => p.name == 'ohos',
      );
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const channel = MethodChannel('harmonyChannel');
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final key = GlobalKey<NavigatorState>();
      final observer = ShellBarsObserver();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          navigatorObservers: [observer],
          home: const Scaffold(body: Text('home')),
        ),
      );
      await tester.pumpAndSettle();
      double exposure() =>
          (calls
                      .lastWhere((c) => c.method == 'setTopBarExposure')
                      .arguments['fraction']
                  as num)
              .toDouble();
      final page = PageRouteBuilder<void>(
        settings: const RouteSettings(name: '/videoV'),
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, __, ___) => const Scaffold(body: Text('video')),
      );
      key.currentState!.push(page);
      await tester.pump();
      expect(exposure(), 1);
      await tester.pump(const Duration(milliseconds: 120));
      expect(exposure(), inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(exposure(), 0);
      key.currentState!.pop();
      await tester.pump();
      expect(
        exposure(),
        0,
      ); // didPop must not reveal the whole header over the video.
      await tester.pump(const Duration(milliseconds: 120));
      expect(exposure(), inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(exposure(), 1);
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
