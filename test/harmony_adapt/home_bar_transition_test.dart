import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/harmony_adapt/shell_bars_observer.dart';
import 'package:PiliPlus/harmony_adapt/harmony_motion.dart';

PageRouteBuilder<void> _videoCover() => PageRouteBuilder<void>(
  settings: const RouteSettings(name: '/videoV'),
  transitionDuration: const Duration(milliseconds: 300),
  reverseTransitionDuration: const Duration(milliseconds: 300),
  pageBuilder: (_, __, ___) => const Scaffold(body: Text('video')),
);

void main() {
  test('interactive coverage follows the finger exactly', () {
    expect(HarmonyMotion.pageCoverage(.3, interactive: true), .3);
    expect(HarmonyMotion.pageCoverage(0, interactive: false), 0);
    expect(HarmonyMotion.pageCoverage(1, interactive: false), 1);
  });
  testWidgets(
    'native header tracks actual route progress in both directions',
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
      final page = _videoCover();
      key.currentState!.push(page);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(
        exposure(),
        closeTo(1 - HarmonyMotion.pageCoverage(.4, interactive: false), .002),
      );
      expect(
        calls.lastWhere((c) => c.method == 'setTopBarExposure').arguments,
        {'fraction': exposure()},
      );
      final beforeMeasurement = exposure();
      page.offstage = true;
      await tester.pump();
      expect(exposure(), beforeMeasurement);
      page.offstage = false;
      await tester.pump(const Duration(milliseconds: 30));
      expect(exposure(), closeTo(.5, .002));
      await tester.pumpAndSettle();
      expect(exposure(), 0);
      expect(
        calls
            .lastWhere((c) => c.method == 'setShellBarsHidden')
            .arguments['hidden'],
        false,
      );
      expect(
        calls
            .lastWhere((c) => c.method == 'setShellBarsScrollHidden')
            .arguments['hidden'],
        false,
      );
      page.handleStartBackGesture(progress: 1);
      page.handleUpdateBackGestureProgress(progress: .7);
      await tester.pump();
      expect(exposure(), closeTo(.3, .002));
      page.handleCancelBackGesture();
      await tester.pumpAndSettle();
      expect(
        exposure(),
        0,
        reason: 'cancelling a back swipe covers the bar again',
      );
      key.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(
        exposure(),
        closeTo(HarmonyMotion.pageCoverage(.4, interactive: false), .002),
      );
      await tester.pumpAndSettle();
      expect(exposure(), 1);
      showModalBottomSheet<void>(
        context: key.currentContext!,
        builder: (_) => const Text('sheet'),
      );
      await tester.pumpAndSettle();
      expect(exposure(), 0);
      key.currentState!.pop();
      await tester.pumpAndSettle();
      expect(exposure(), 1);
      key.currentState!.push(_videoCover());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(exposure(), inExclusiveRange(0, 1));
      key.currentState!.pop();
      await tester.pumpAndSettle();
      expect(
        exposure(),
        1,
        reason: 'quick push-pop fully exposes the same bar',
      );
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    },
  );
  testWidgets(
    'nested routes skip unchanged shell flags and can be torn down together',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.ohos;
      const channel = MethodChannel('harmonyChannel');
      final calls = <MethodCall>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      try {
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
        observer.onOrientationChanged(true);
        await tester.pumpAndSettle();
        final flagMethods = {'setShellBarsHidden', 'setShellBarsObscured'};
        List<MethodCall> flags() =>
            calls.where((call) => flagMethods.contains(call.method)).toList();
        calls.clear();
        key.currentState!.push(
          PageRouteBuilder<void>(
            pageBuilder: (_, __, ___) => const Scaffold(body: Text('first')),
          ),
        );
        await tester.pumpAndSettle();
        expect(flags(), isEmpty);
        calls.clear();
        key.currentState!.push(
          PageRouteBuilder<void>(
            pageBuilder: (_, __, ___) => const Scaffold(body: Text('second')),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          calls.where((call) => call.method == 'setTopBarExposure'),
          isEmpty,
        );
        expect(flags(), isEmpty);
        observer.onOrientationChanged(true);
        await tester.pumpAndSettle();
        expect(
          flags().map((call) => call.method),
          unorderedEquals(flagMethods),
        );
        expect(
          flags()
              .firstWhere((call) => call.method == 'setShellBarsHidden')
              .arguments,
          {'hidden': false, 'force': true},
        );
        calls.clear();
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        expect(
          calls,
          isEmpty,
          reason: 'teardown must not retrack a disposed cover',
        );
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: key,
            navigatorObservers: [observer],
            home: const Scaffold(body: Text('new home')),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          calls.lastWhere((c) => c.method == 'setTopBarExposure').arguments,
          {'fraction': 1.0},
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      } finally {
        messenger.setMockMethodCallHandler(channel, null);
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
