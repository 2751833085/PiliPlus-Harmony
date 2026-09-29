import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/plugin/pl_player/widgets/danmaku_action_transition.dart';

void main() {
  testWidgets(
    'anchored danmaku actions fade in/out and cannot act while leaving',
    (tester) async {
      var taps = 0;
      Widget scene(bool visible) => MaterialApp(
        home: Scaffold(
          body: DanmakuActionTransition(
            child: visible
                ? Stack(
                    key: const ValueKey('menu'),
                    children: [
                      Positioned(
                        left: 30,
                        top: 60,
                        child: GestureDetector(
                          onTap: () => taps++,
                          child: const SizedBox(
                            width: 120,
                            height: 40,
                            child: Text('点赞'),
                          ),
                        ),
                      ),
                    ],
                  )
                : null,
          ),
        ),
      );
      await tester.pumpWidget(scene(false));
      await tester.pumpWidget(scene(true));
      await tester.pump(const Duration(milliseconds: 60));
      final fade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.text('点赞'),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, greaterThan(0));
      expect(fade.opacity.value, lessThan(1));
      expect(tester.getTopLeft(find.text('点赞')), const Offset(30, 60));
      await tester.pumpAndSettle();
      await tester.tap(find.text('点赞'));
      expect(taps, 1);
      await tester.pumpWidget(scene(false));
      await tester.pump(const Duration(milliseconds: 30));
      expect(find.text('点赞'), findsOneWidget);
      await tester.tapAt(const Offset(40, 70));
      expect(taps, 1);
      await tester.pumpAndSettle();
      expect(find.text('点赞'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
