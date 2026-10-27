import 'package:flutter/material.dart';
import 'package:PiliPlus/harmony_adapt/widgets/harmony_loading.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/harmony_adapt/widgets/native_loading_opacity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'alpha reaches native view, coalesces frames and delivers final zero',
    (tester) async {
      final values = <double>[];
      final first = Completer<void>();
      const channel = MethodChannel('piliplus/native-loading/41');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        expectSync(call.method, 'setOpacity');
        values.add(call.arguments as double);
        if (values.length == 1) await first.future;
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final bridge = NativeLoadingOpacity();
      bridge.update(.1);
      bridge.attach(41);
      await tester.pump();
      for (final value in [.2, .4, .8, 1.0]) {
        bridge.update(value);
      }
      expect(values, [.1]);
      first.complete();
      await tester.pump();
      expect(values, [.1, 1.0]);
      bridge.update(.5);
      await tester.pump();
      bridge.update(0);
      await tester.pump();
      expect(values, [.1, 1.0, .5, 0.0]);
      bridge.dispose();
      bridge.update(1);
      await tester.pump();
      expect(values.last, 0);
    },
  );
  testWidgets('recreated views get current alpha without stale updates', (
    tester,
  ) async {
    final old = Completer<void>();
    final values = <double>[];
    const a = MethodChannel('piliplus/native-loading/42');
    const b = MethodChannel('piliplus/native-loading/43');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      a,
      (_) => old.future,
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(b, (
      call,
    ) async {
      values.add(call.arguments as double);
      return null;
    });
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(a, null);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(b, null);
    });
    final bridge = NativeLoadingOpacity()
      ..update(.2)
      ..attach(42);
    await tester.pump();
    bridge.update(.7);
    bridge.attach(43);
    await tester.pump();
    expect(values, [
      .7,
    ], reason: 'new channel must not wait for the old invoke');
    old.complete();
    await tester.pump();
    expect(values, [.7]);
    bridge.dispose();
  });
  for (final oldFails in [false, true]) {
    testWidgets(
      'retired ${oldFails ? 'failure' : 'completion'} cannot release a new in-flight send',
      (tester) async {
        final old = Completer<void>(), next = Completer<void>();
        final values = <double>[];
        final logs = <String?>[];
        final oldPrint = debugPrint;
        debugPrint = (String? message, {int? wrapWidth}) => logs.add(message);
        addTearDown(() => debugPrint = oldPrint);
        const a = MethodChannel('piliplus/native-loading/51');
        const b = MethodChannel('piliplus/native-loading/52');
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(a, (
          _,
        ) async {
          await old.future;
          if (oldFails) throw MissingPluginException('retired view');
          return null;
        });
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(b, (
          call,
        ) async {
          values.add(call.arguments as double);
          if (values.length == 1) await next.future;
          return null;
        });
        addTearDown(() {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            a,
            null,
          );
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            b,
            null,
          );
        });
        final bridge = NativeLoadingOpacity()
          ..update(.2)
          ..attach(51);
        await tester.pump();
        final retiredGeneration = bridge.detach();
        final liveGeneration = bridge.detach();
        bridge.update(.7);
        expect(bridge.attach(52, generation: liveGeneration), isTrue);
        await tester.pump();
        expect(values, [.7]);
        expect(bridge.canAttach(retiredGeneration), isFalse);
        expect(bridge.attach(51, generation: retiredGeneration), isFalse);
        old.complete();
        await tester.pump();
        bridge.update(0);
        await tester.pump();
        expect(
          values,
          [.7],
          reason: 'retired completion must not clear the live sending state',
        );
        next.complete();
        await tester.pump();
        expect(values, [.7, 0]);
        expect(
          logs,
          isEmpty,
          reason: 'only explicitly stale failures are ignored',
        );
        bridge.dispose();
        expect(bridge.attach(51), isFalse);
        bridge.update(1);
        await tester.pump();
        expect(values, [.7, 0]);
        debugPrint = oldPrint;
      },
    );
  }

  testWidgets(
    'active failure remains diagnostic and a changed final zero is delivered',
    (tester) async {
      final logs = <String?>[];
      final oldPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) => logs.add(message);
      addTearDown(() => debugPrint = oldPrint);
      final first = Completer<void>();
      final values = <double>[];
      const channel = MethodChannel('piliplus/native-loading/61');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        values.add(call.arguments as double);
        if (values.length == 1) {
          await first.future;
          throw PlatformException(code: 'active-channel-failed');
        }
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final bridge = NativeLoadingOpacity()
        ..update(.5)
        ..attach(61);
      await tester.pump();
      bridge.update(0);
      first.complete();
      await tester.pump();
      expect(logs.single, contains('active-channel-failed'));
      expect(values, [.5, 0]);
      bridge.dispose();
      debugPrint = oldPrint;
    },
  );
  testWidgets(
    'fallback completes 220ms entry when opacity updates during entrance',
    (tester) async {
      final oldPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = oldPlatform);
      var opacity = 1.0;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (_, setState) {
              update = setState;
              return Center(
                child: HarmonyLoadingIndicator(value: .5, opacity: opacity),
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final alpha = find.descendant(
        of: find.byType(HarmonyLoadingIndicator),
        matching: find.byType(Opacity),
      );
      expect(tester.widget<Opacity>(alpha).opacity, inExclusiveRange(0, 1));
      update(() => opacity = .5);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 140));
      expect(tester.widget<Opacity>(alpha).opacity, closeTo(.5, .001));
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = oldPlatform;
    },
  );
}
