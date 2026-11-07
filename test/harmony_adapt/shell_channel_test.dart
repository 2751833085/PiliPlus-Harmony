import 'dart:async';

import 'package:PiliPlus/harmony_adapt/harmony_channel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('harmonyChannel');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.values.firstWhere(
      (platform) => platform.name == 'ohos',
    );
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'shell visibility completes only after the native acknowledgement',
    () async {
      final acknowledgement = Completer<void>();
      messenger.setMockMethodCallHandler(
        channel,
        (_) => acknowledgement.future,
      );
      var completed = false;
      final update = HarmonyChannel.setShellBarsHidden(true).then((_) {
        completed = true;
      });
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);
      acknowledgement.complete();
      await update;
      expect(completed, isTrue);
    },
  );

  test('asynchronous shell failure is retried and resolved', () async {
    var calls = 0;
    messenger.setMockMethodCallHandler(channel, (_) async {
      if (++calls == 1) throw PlatformException(code: 'WINDOW_NOT_READY');
      return null;
    });
    await HarmonyChannel.setShellBarsHidden(false, retry: true);
    expect(calls, 2);
  });

  test('a failed old hide cannot retry over a newer visible route', () async {
    final old = Completer<void>();
    final requests = <bool>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      requests.add(call.arguments['hidden'] as bool);
      if (requests.length == 1) await old.future;
      return null;
    });
    final hiding = HarmonyChannel.setShellBarsHidden(true, retry: true);
    await Future<void>.delayed(Duration.zero);
    await HarmonyChannel.setShellBarsHidden(false, force: true);
    old.completeError(PlatformException(code: 'WINDOW_NOT_READY'));
    await hiding;
    expect(requests, [true, false]);
    expect(HarmonyChannel.hdsBarVisible, isTrue);
  });

  test('top-bar route and tab visibility share guarded native calls', () async {
    final requests = <bool>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'setTopBarHidden') {
        requests.add(call.arguments['hidden'] as bool);
        throw PlatformException(code: 'WINDOW_NOT_READY');
      }
      return null;
    });
    await HarmonyChannel.setTopBarHidden(true);
    await HarmonyChannel.setTopBarTabHidden(true);
    await HarmonyChannel.setTopBarHidden(false);
    await HarmonyChannel.setTopBarTabHidden(false);
    expect(requests, [true, true, true, false]);
  });

  test('optional shell calls tolerate an unavailable native plugin', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) => Future<Object?>.error(MissingPluginException()),
    );
    await HarmonyChannel.setShellBarsHidden(false);
    await HarmonyChannel.setTopBarHidden(false);
    await HarmonyChannel.setTopBarTabHidden(false);
    await HarmonyChannel.setShellBars(useNativeTabs: true);
  });
  test(
    'ordinary visibility sync skips acknowledged state and explicit sync resends',
    () async {
      final requests = <Map<Object?, Object?>>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        requests.add(call.arguments as Map<Object?, Object?>);
        if (requests.length == 1) {
          throw PlatformException(code: 'WINDOW_NOT_READY');
        }
        return null;
      });
      await HarmonyChannel.setShellBarsHidden(true, force: true);
      await HarmonyChannel.setShellBarsHidden(
        true,
        force: true,
        skipUnchanged: true,
      );
      await HarmonyChannel.setShellBarsHidden(
        true,
        force: true,
        skipUnchanged: true,
      );
      expect(requests, [
        {'hidden': true, 'force': true},
        {'hidden': true, 'force': true},
      ], reason: 'only an acknowledged state may be skipped');
      await HarmonyChannel.setShellBarsHidden(true, force: true);
      await HarmonyChannel.setShellBarsHidden(true);
      await HarmonyChannel.setShellBarsHidden(
        true,
        force: true,
        skipUnchanged: true,
      );
      expect(requests.map((args) => args['force']), [
        true,
        true,
        true,
        false,
        true,
      ]);
    },
  );

  test(
    'a delayed obscured acknowledgement cannot replace the current state',
    () async {
      final old = Completer<void>();
      final requests = <Map<Object?, Object?>>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        requests.add(call.arguments as Map<Object?, Object?>);
        if (requests.length == 1) await old.future;
        return null;
      });
      final covering = HarmonyChannel.setShellBarsObscured(true);
      await Future<void>.delayed(Duration.zero);
      await HarmonyChannel.setShellBarsObscured(false);
      old.complete();
      await covering;
      await HarmonyChannel.setShellBarsObscured(false, skipUnchanged: true);
      await HarmonyChannel.setShellBarsObscured(
        true,
        blur: false,
        skipUnchanged: true,
      );
      await HarmonyChannel.setShellBarsObscured(true, skipUnchanged: true);
      expect(requests, [
        {'obscured': true, 'blur': true},
        {'obscured': false, 'blur': false},
        {'obscured': true, 'blur': false},
        {'obscured': true, 'blur': true},
      ]);
      await HarmonyChannel.setShellBarsObscured(false);
    },
  );

  test(
    'native coverage sends the latest fraction and the final zero',
    () async {
      final first = Completer<void>();
      final requests = <Map<Object?, Object?>>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        requests.add(call.arguments as Map<Object?, Object?>);
        if (requests.length == 1) await first.future;
        return null;
      });
      final sending = HarmonyChannel.setTopBarExposure(.8);
      await Future<void>.delayed(Duration.zero);
      await HarmonyChannel.setTopBarExposure(.5);
      await HarmonyChannel.setTopBarExposure(.25);
      await HarmonyChannel.setTopBarExposure(0);
      expect(requests, [
        {'fraction': .8},
      ]);
      first.complete();
      await sending;
      expect(requests, [
        {'fraction': .8},
        {'fraction': 0.0},
      ]);
    },
  );
}
