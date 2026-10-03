import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/pages/video/widgets/video_entrance.dart';

void main() {
  testWidgets('early return cancels deferred player initialization', (
    tester,
  ) async {
    final key = GlobalKey<NavigatorState>();
    Future<bool>? entered;
    await tester.pumpWidget(
      MaterialApp(navigatorKey: key, home: const SizedBox()),
    );
    key.currentState!.push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, _, __) {
          entered = waitForVideoEntrance(context);
          return const SizedBox.expand();
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    key.currentState!.pop();
    await tester.pumpAndSettle();
    expect(await entered, false);
    expect(tester.takeException(), isNull);
  });
  testWidgets('an options dialog during entrance does not cancel the player', (
    tester,
  ) async {
    final key = GlobalKey<NavigatorState>();
    Future<bool>? entered;
    BuildContext? pageContext;
    await tester.pumpWidget(
      MaterialApp(navigatorKey: key, home: const SizedBox()),
    );
    key.currentState!.push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, _, __) {
          pageContext = context;
          entered ??= waitForVideoEntrance(context);
          return const SizedBox.expand();
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    showDialog<void>(
      context: pageContext!,
      builder: (_) => const AlertDialog(content: Text('options')),
    );
    await tester.pumpAndSettle();
    expect(await entered, true);
    key.currentState!.pop();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
