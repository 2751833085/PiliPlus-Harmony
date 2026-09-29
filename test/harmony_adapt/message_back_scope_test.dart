import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/pages/whisper/widgets/message_back_scope.dart';

void main() {
  for (final split in [false, true]) {
    testWidgets(
      'back with split=$split preserves the expected navigation depth',
      (tester) async {
        final navigator = GlobalKey<NavigatorState>();
        var closed = 0;
        await tester.pumpWidget(
          MaterialApp(navigatorKey: navigator, home: const Text('首页')),
        );
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => MessageBackScope(
              split: split,
              hasSelection: true,
              onCloseSelection: () => closed++,
              child: const Scaffold(body: Text('消息会话')),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await navigator.currentState!.maybePop();
        await tester.pumpAndSettle();
        expect(closed, split ? 0 : 1);
        expect(find.text('消息会话'), split ? findsNothing : findsOneWidget);
      },
    );
  }
}
