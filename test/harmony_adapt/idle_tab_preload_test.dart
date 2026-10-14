import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/harmony_adapt/widgets/idle_tab_preload.dart';

void main() {
  testWidgets('neighbour preparation waits until entrance ends', (
    tester,
  ) async {
    final nav = GlobalKey<NavigatorState>();
    final prepared = <bool>[];
    await tester.pumpWidget(
      MaterialApp(navigatorKey: nav, home: const SizedBox()),
    );
    nav.currentState!.push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, __, ___) => IdleTabPreload(
          builder: (_, ready) {
            prepared.add(ready);
            return const SizedBox.expand();
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.idle();
    expect(prepared, isNot(contains(true)));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 40));
    expect(prepared, contains(true));
  });
  testWidgets(
    'rapid return cancels neighbour mounts during the reverse animation',
    (tester) async {
      final nav = GlobalKey<NavigatorState>();
      final prepared = <bool>[];
      await tester.pumpWidget(
        MaterialApp(navigatorKey: nav, home: const SizedBox()),
      );
      nav.currentState!.push(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (_, __, ___) => IdleTabPreload(
            builder: (_, ready) {
              prepared.add(ready);
              return const SizedBox.expand();
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      await tester.idle();
      expect(prepared, isNot(contains(true)));
      expect(tester.takeException(), isNull);
    },
  );
}
