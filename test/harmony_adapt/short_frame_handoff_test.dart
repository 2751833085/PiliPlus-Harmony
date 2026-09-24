import 'package:PiliPlus/plugin/pl_player/models/source_frame_gate.dart';
import 'package:PiliPlus/pages/video/shorts/frame_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('each media load requires its own finite video timestamp', () {
    final gate = SourceFrameGate();
    final a = gate.begin('a');
    expect(gate.accept(a, source: 'a', pts: '0'), isTrue);
    final b = gate.begin('b');
    expect(gate.ready, isFalse);
    expect(gate.accept(a, source: 'a', pts: '2.1'), isFalse);
    expect(gate.accept(b, source: 'a', pts: '2.1'), isFalse);
    for (final invalid in ['', 'null', 'NaN', 'Infinity', '-1']) {
      expect(gate.accept(b, source: 'b', pts: invalid), isFalse);
    }
    expect(gate.ready, isFalse);
    expect(gate.accept(b, source: 'b', pts: '0.000000'), isTrue);
    gate.invalidate();
    expect(gate.accept(b, source: 'b', pts: '0.040000'), isFalse);
    gate.dispose();
  });

  testWidgets(
    'preview stays above opaque texture until new frame handoff and resets on rapid swipe',
    (tester) async {
      Widget page(String source, bool ready) => MaterialApp(
        home: Stack(
          children: [
            const ColoredBox(color: Colors.black, child: SizedBox.expand()),
            ShortFrameOverlay(
              key: ValueKey(source),
              ready: ready,
              child: const ColoredBox(
                color: Colors.green,
                child: SizedBox.expand(),
              ),
            ),
          ],
        ),
      );
      await tester.pumpWidget(page('a', false));
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        1,
      );
      await tester.pumpWidget(page('a', true));
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        1,
      );
      await tester.pump();
      await tester.pump();
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        0,
      );
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pumpWidget(page('b', false));
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        1,
      );
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        1,
      );
      await tester.pumpWidget(page('b', true));
      await tester.pumpAndSettle();
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        0,
      );
    },
  );
}
