import 'dart:async';
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
    old.complete();
    await tester.pump();
    expect(values, [.7]);
    bridge.dispose();
  });
}
