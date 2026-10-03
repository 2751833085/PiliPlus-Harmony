import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';

void main() {
  testWidgets('page covers from right without fading and reverses to right', (
    tester,
  ) async {
    final animation = AnimationController(
      vsync: tester,
      duration: const Duration(milliseconds: 300),
    );
    addTearDown(animation.dispose);
    final secondary = AnimationController(
      vsync: tester,
      duration: const Duration(milliseconds: 300),
    );
    addTearDown(secondary.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: HarmonyPageTransitionsBuilder(),
              TargetPlatform.iOS: HarmonyPageTransitionsBuilder(),
            },
          ),
        ),
        home: Builder(
          builder: (context) {
            return const HarmonyPageTransitionsBuilder().buildTransitions(
              MaterialPageRoute<void>(builder: (_) => const SizedBox()),
              context,
              animation,
              secondary,
              const SizedBox.expand(key: ValueKey('page')),
            );
          },
        ),
      ),
    );
    expect(tester.getTopLeft(find.byKey(const ValueKey('page'))).dx, 800);
    animation.value = .5;
    await tester.pump();
    final x = tester.getTopLeft(find.byKey(const ValueKey('page'))).dx;
    expect(x, greaterThan(0));
    expect(x, lessThan(800));
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('page')),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );
    animation.value = 1;
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(const ValueKey('page'))).dx, 0);
    animation.value = .5;
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(const ValueKey('page'))).dx, x);
    animation.value = 1;
    secondary.value = .5;
    await tester.pump();
    final behind = tester.getTopLeft(find.byKey(const ValueKey('page'))).dx;
    expect(behind, inExclusiveRange(-160, 0));
    secondary.value = 0;
    animation.reverse();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('page'))).dx,
      inExclusiveRange(0, 800),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(const ValueKey('page'))).dx, 800);
  });
}
