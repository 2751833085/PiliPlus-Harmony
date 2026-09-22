import 'package:PiliPlus/pages/video/shorts/mode_transition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'mode fade retains one player across reparenting and rejects reentry',
    (tester) async {
      final transition = GlobalKey<PlayerModeTransitionState>();
      final player = GlobalKey<_PlayerState>();
      late StateSetter setLayout;
      var short = false;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              setLayout = setState;
              return PlayerModeTransition(
                key: transition,
                child: short
                    ? Stack(
                        children: [
                          Positioned.fill(child: _Player(key: player)),
                        ],
                      )
                    : Column(
                        children: [Expanded(child: _Player(key: player))],
                      ),
              );
            },
          ),
        ),
      );
      final initial = player.currentState;
      final pending = transition.currentState!.change(
        () => setLayout(() => short = true),
      );
      expect(
        await transition.currentState!.change(
          () => fail('duplicate transition'),
        ),
        isFalse,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(short, isFalse);
      expect(
        tester
            .widget<FadeTransition>(find.byType(FadeTransition).last)
            .opacity
            .value,
        lessThan(1),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();
      expect(short, isTrue);
      expect(find.byType(_Player, skipOffstage: false), findsOneWidget);
      expect(player.currentState, same(initial));
      await tester.pumpAndSettle();
      expect(await pending, isTrue);
      final back = transition.currentState!.change(
        () => setLayout(() => short = false),
      );
      await tester.pumpAndSettle();
      expect(await back, isTrue);
      expect(player.currentState, same(initial));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reduced motion switches immediately and disposal cancels cleanly',
    (tester) async {
      final key = GlobalKey<PlayerModeTransitionState>();
      var calls = 0;
      Widget build(bool reduce) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduce),
          child: PlayerModeTransition(key: key, child: const SizedBox.expand()),
        ),
      );
      await tester.pumpWidget(build(true));
      expect(await key.currentState!.change(() => calls++), isTrue);
      expect(calls, 1);
      await tester.pumpWidget(build(false));
      final pending = key.currentState!.change(() => calls++);
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      expect(await pending, isFalse);
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    },
  );
}

class _Player extends StatefulWidget {
  const _Player({super.key});
  @override
  State<_Player> createState() => _PlayerState();
}

class _PlayerState extends State<_Player> {
  @override
  Widget build(BuildContext context) => const ColoredBox(color: Colors.black);
}
