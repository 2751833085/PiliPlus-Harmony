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
  testWidgets(
    'side panel slides horizontally and one back closes a replacement',
    (tester) async {
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
                  child: MiniScaffold(key: sidebar, body: const Text('intro')),
                ),
              ],
            ),
          ),
        ),
      );
      void open(String title) => sidebar.currentState!.showBottomSheet(
        (_) => SizedBox.expand(key: ValueKey(title), child: Text(title)),
        constraints: const BoxConstraints(),
        slideFromRight: true,
        sheetAnimationStyle: const AnimationStyle(
          duration: Duration(milliseconds: 300),
          reverseDuration: Duration(milliseconds: 300),
        ),
      );
      open('member');
      await tester.pump();
      final member = find.byKey(const ValueKey('member'));
      expect(tester.getTopLeft(member).dx, 800);
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.getTopLeft(member).dx, closeTo(660, 1));
      expect(tester.getTopLeft(member).dy, 0);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(member).dx, 520);
      open('playlist');
      await tester.pumpAndSettle();
      expect(member, findsNothing);
      expect(find.text('playlist'), findsOneWidget);
      await navigator.currentState!.maybePop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      final playlist = find.byKey(const ValueKey('playlist'));
      expect(tester.getTopLeft(playlist).dx, closeTo(660, 1));
      await tester.pumpAndSettle();
      expect(playlist, findsNothing);
      expect(find.text('video'), findsOneWidget);
      expect(find.text('intro'), findsOneWidget);
      expect(navigator.currentState!.canPop(), isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
