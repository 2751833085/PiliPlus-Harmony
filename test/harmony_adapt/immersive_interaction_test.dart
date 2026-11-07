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
    'nested surfaces stay fixed while touch feedback clears after cancellation',
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
      final innerSurface = find.byKey(inner);
      final outerSurface = find.byKey(outer);
      final innerPaint = _lightPaint(innerSurface);
      final outerPaint = _lightPaint(outerSurface);
      final innerBounds = tester.getRect(innerSurface);
      final outerBounds = tester.getRect(outerSurface);
      final paintWidget = tester.widget<CustomPaint>(innerPaint);
      final gesture = await tester.startGesture(tester.getCenter(innerSurface));
      await gesture.moveBy(const Offset(10, 0));
      await tester.pump();
      expect(tester.getRect(innerSurface), innerBounds);
      expect(tester.getRect(outerSurface), outerBounds);
      _expectLight(tester, innerPaint, visible: true);
      _expectLight(tester, outerPaint, visible: false);
      await gesture.cancel();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.widget<CustomPaint>(innerPaint), same(paintWidget));
      _expectLight(tester, innerPaint, visible: true);
      await tester.pumpAndSettle();
      _expectLight(tester, innerPaint, visible: false);
      expect(tester.binding.transientCallbackCount, 0);
    },
  );
  testWidgets('background and removal clear active pointer feedback', (
    tester,
  ) async {
    const control = ValueKey('control');
    await tester.pumpWidget(
      MaterialApp(
        theme: HarmonyTheme.apply(ThemeData.dark(), immersive: true),
        home: const Scaffold(
          body: Center(
            child: ImmersiveInteraction(
              key: control,
              child: SizedBox(
                width: 100,
                height: 60,
                child: ColoredBox(color: Colors.grey),
              ),
            ),
          ),
        ),
      ),
    );
    final surface = find.byKey(control);
    final paint = _lightPaint(surface);
    for (final releaseFirst in [false, true]) {
      final gesture = await tester.startGesture(tester.getCenter(surface));
      if (releaseFirst) await gesture.up();
      await tester.pump();
      _expectLight(tester, paint, visible: true);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      if (!releaseFirst) await gesture.up();
      await tester.pump();
      _expectLight(tester, paint, visible: false);
      expect(tester.binding.transientCallbackCount, 0);
    }
    final last = await tester.startGesture(tester.getCenter(surface));
    await last.up();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search movement is opt-in and sliders do not move their panel', (
    tester,
  ) async {
    var value = .5;
    await tester.pumpWidget(
      MaterialApp(
        theme: HarmonyTheme.apply(ThemeData.dark(), immersive: true),
        home: Scaffold(
          body: Column(
            children: [
              const ImmersiveSurface(
                allowMovement: true,
                child: SizedBox(
                  key: ValueKey('search'),
                  width: 220,
                  height: 50,
                ),
              ),
              ImmersiveSurface(
                child: StatefulBuilder(
                  builder: (context, setState) => Slider(
                    value: value,
                    onChanged: (v) => setState(() => value = v),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final search = find.byKey(const ValueKey('search'));
    final original = tester.getTopLeft(search);
    final finger = await tester.startGesture(tester.getCenter(search));
    await finger.moveBy(const Offset(10, 0));
    await tester.pump();
    expect(tester.getTopLeft(search).dx, greaterThan(original.dx));
    await finger.up();
    await tester.pumpAndSettle();
    final slider = find.byType(Slider);
    final position = tester.getTopLeft(slider);
    final drag = await tester.startGesture(tester.getCenter(slider));
    await drag.moveBy(const Offset(12, 0));
    await tester.pump();
    expect(tester.getTopLeft(slider), position);
    await drag.moveBy(const Offset(90, 0));
    await tester.pump();
    expect(tester.getTopLeft(slider), position);
    expect(value, greaterThan(.5));
    await drag.up();
    await tester.pumpAndSettle();
  });
}

Finder _lightPaint(Finder surface) => find
    .descendant(
      of: surface,
      matching: find.byType(CustomPaint),
    )
    .first;

void _expectLight(WidgetTester tester, Finder paint, {required bool visible}) {
  final painter = tester.widget<CustomPaint>(paint).foregroundPainter!;
  final size = tester.getSize(paint);
  expect(
    (Canvas canvas) => painter.paint(canvas, size),
    paintsExactlyCountTimes(#drawCircle, visible ? 1 : 0),
  );
}
