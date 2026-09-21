import 'package:PiliPlus/harmony_adapt/widgets/cover_hero.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'the player remains mounted for the whole cover flight and return',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final probe = GlobalKey<_ProbeState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: Hero(
                tag: 'cover',
                createRectTween: CoverHero.rectTween,
                flightShuttleBuilder: (_, animation, direction, from, to) =>
                    const ColoredBox(color: Colors.blue),
                child: const SizedBox(
                  width: 200,
                  height: 112,
                  child: ColoredBox(color: Colors.blue),
                ),
              ),
            ),
          ),
        ),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: Hero(
                tag: 'cover',
                createRectTween: CoverHero.rectTween,
                placeholderBuilder: CoverHero.playerPlaceholder,
                child: SizedBox(
                  width: 600,
                  height: 338,
                  child: _Probe(key: probe),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final state = probe.currentState!;
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        expect(identical(probe.currentState, state), isTrue);
        expect(state.disposed, isFalse);
      }
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(probe)), const Size(600, 338));
      navigator.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(state.disposed, isFalse);
      await tester.pumpAndSettle();
      expect(state.disposed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}

class _Probe extends StatefulWidget {
  const _Probe({super.key});
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  bool disposed = false;
  @override
  Widget build(BuildContext context) => const ColoredBox(color: Colors.black);
  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}
