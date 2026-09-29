import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/harmony_adapt/widgets/navigation_press_feedback.dart';

void main() {
  testWidgets(
    'navigation taps keep their action and cancellation releases feedback',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NavigationPressFeedback(
              child: TextButton(
                onPressed: () => taps++,
                child: const Text('首页'),
              ),
            ),
          ),
        ),
      );
      final target = find.text('首页');
      final press = await tester.startGesture(tester.getCenter(target));
      await tester.pump();
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        .94,
      );
      await press.cancel();
      await tester.pumpAndSettle();
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
      expect(taps, 0);
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(taps, 1);
    },
  );

  testWidgets('reduced motion keeps navigation buttons stationary', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: NavigationPressFeedback(
              child: SizedBox(width: 80, height: 48),
            ),
          ),
        ),
      ),
    );
    final press = await tester.startGesture(
      tester.getCenter(find.byType(NavigationPressFeedback)),
    );
    await tester.pump();
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    await press.up();
    await tester.pumpAndSettle();
  });
}
