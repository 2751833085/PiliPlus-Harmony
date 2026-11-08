import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:PiliPlus/harmony_adapt/harmony_motion.dart';

void main() {
  test(
    'enter and exit have mirrored displacement throughout the animation',
    () {
      for (var i = 0; i <= 100; i++) {
        final t = i / 100;
        final enter = HarmonyMotion.pageCoverage(t, interactive: false);
        final exit = HarmonyMotion.pageCoverage(
          1 - t,
          interactive: false,
          reverse: true,
        );
        expect(enter + exit, closeTo(1, .002));
        expect(
          HarmonyMotion.pageCoverage(t, interactive: false, reverse: true),
          closeTo(enter, .002),
        );
        expect(HarmonyMotion.pageCoverage(t, interactive: true), t);
      }
    },
  );
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
    final page = find.byKey(const ValueKey('page'));
    expect(tester.getTopLeft(page).dx, 800);
    animation.value = .5;
    await tester.pump();
    final x = tester.getTopLeft(page).dx;
    expect(x, greaterThan(0));
    expect(x, lessThan(800));
    expect(
      find.ancestor(
        of: page,
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );
    animation.value = 1;
    await tester.pump();
    final settledPosition = tester.getTopLeft(page);
    expect(settledPosition.dx, 0);
    animation.value = .5;
    await tester.pump();
    expect(tester.getTopLeft(page).dx, x);

    // A route above the settled page covers and reveals the same position.
    animation.value = 1;
    for (final progress in [.02, .25, .5, .75, 1.0, .75, .5, .25, .02, 0.0]) {
      secondary.value = progress;
      await tester.pump();
      expect(
        tester.getTopLeft(page),
        settledPosition,
        reason: 'settled page moves at secondary coverage $progress',
      );
    }
    animation.reverse();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      tester.getTopLeft(page).dx,
      inExclusiveRange(0, 800),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(page).dx, 800);
  });
}
