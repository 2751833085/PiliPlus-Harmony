import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('pointer feedback keeps child cached and allows scrolling', (
    tester,
  ) async {
    var builds = 0;
    var taps = 0;
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: HarmonyTheme.apply(ThemeData.light(), immersive: true),
        home: Scaffold(
          body: ListView(
            controller: scroll,
            children: [
              ImmersiveSurface(
                child: Builder(
                  builder: (_) {
                    builds++;
                    return SizedBox(
                      height: 100,
                      child: TextButton(
                        onPressed: () => taps++,
                        child: const Text('Action'),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 1800),
            ],
          ),
        ),
      ),
    );
    final before = builds;
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Action')),
    );
    await gesture.moveBy(const Offset(6, 3));
    await tester.pump(const Duration(milliseconds: 16));
    expect(builds, before);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(tester.binding.transientCallbackCount, 0);
    await tester.drag(find.text('Action'), const Offset(0, -250));
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(0));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'nested surfaces animate only deepest target and clear after cancellation',
    (tester) async {
      const outer = ValueKey('outer');
      const inner = ValueKey('inner');
      await tester.pumpWidget(
        MaterialApp(
          theme: HarmonyTheme.apply(ThemeData.dark(), immersive: true),
          home: const Scaffold(
            body: Center(
              child: ImmersiveInteraction(
                key: outer,
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: ImmersiveInteraction(
                    key: inner,
                    child: SizedBox(
                      width: 100,
                      height: 60,
                      child: ColoredBox(color: Colors.grey),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(inner)),
      );
      await gesture.moveBy(const Offset(10, 0));
      await tester.pump();
      final transforms = tester
          .widgetList<Transform>(
            find.descendant(
              of: find.byKey(outer),
              matching: find.byType(Transform),
            ),
          )
          .toList();
      expect(transforms.first.transform.storage[12], 0);
      expect(transforms.last.transform.storage[12], greaterThan(0));
      await gesture.cancel();
      await tester.pumpAndSettle();
      for (final t in tester.widgetList<Transform>(
        find.descendant(
          of: find.byKey(outer),
          matching: find.byType(Transform),
        ),
      )) {
        expect(t.transform.storage[12], 0);
      }
      expect(tester.binding.transientCallbackCount, 0);
    },
  );
}
