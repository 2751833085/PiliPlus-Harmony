import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/common/widgets/scaffold/mini_scaffold.dart';

void main() {
  testWidgets('reply sheet stays in sidebar and back preserves video route', (
    tester,
  ) async {
    final sidebar = GlobalKey<MiniScaffoldState>();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: Scaffold(
          body: Row(
            children: [
              const Expanded(child: Text('video')),
              SizedBox(
                width: 280,
                child: ClipRect(
                  child: MiniScaffold(
                    key: sidebar,
                    body: const Text('related'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    sidebar.currentState!.showBottomSheet(
      (_) => const SizedBox.expand(
        key: ValueKey('reply-panel'),
        child: Text('reply'),
      ),
      constraints: const BoxConstraints(),
      enableDrag: false,
    );
    await tester.pumpAndSettle();
    final panel = find.byKey(const ValueKey('reply-panel'));
    expect(tester.getSize(panel).width, 280);
    expect(tester.getTopLeft(panel).dx, 520);
    expect(find.text('video'), findsOneWidget);
    await navigator.currentState!.maybePop();
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
    expect(find.text('video'), findsOneWidget);
    expect(find.text('related'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
