import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:PiliPlus/harmony_adapt/widgets/harmony_navigation_surface.dart';
import 'package:PiliPlus/harmony_adapt/widgets/navigation_press_feedback.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('disabled and accessibility modes retain an opaque neutral bar', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      for (final mode in ['bottomOff', 'allOff', 'contrast', 'reduceMotion']) {
        await tester.pumpWidget(
          MaterialApp(
            theme: HarmonyTheme.apply(
              ThemeData(brightness: brightness),
              immersive: mode != 'allOff',
            ),
            home: MediaQuery(
              data: MediaQueryData(
                highContrast: mode == 'contrast',
                disableAnimations: mode == 'reduceMotion',
              ),
              child: Scaffold(
                bottomNavigationBar: HarmonyNavigationSurface(
                  translucent: mode != 'bottomOff',
                  child: const SizedBox(height: 60),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(BackdropFilter), findsNothing, reason: mode);
        final fill = tester.widget<ColoredBox>(
          find.descendant(
            of: find.byType(HarmonyNavigationSurface),
            matching: find.byType(ColoredBox),
          ),
        );
        expect(
          fill.color,
          brightness == Brightness.dark
              ? const Color(0xFF25262A)
              : const Color(0xFFF7F8FA),
        );
      }
    }
  });

  testWidgets('one bounded backdrop stays separate from navigation feedback', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2.875;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final width in [390.0, 740.0, 1108.0]) {
      tester.view.physicalSize = Size(width, 800) * 2.875;
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: HarmonyTheme.apply(ThemeData.dark(), immersive: true),
          home: Scaffold(
            extendBody: true,
            body: ListView.builder(
              itemCount: 40,
              itemBuilder: (_, index) =>
                  SizedBox(height: 80, child: Text('Video $index')),
            ),
            bottomNavigationBar: HarmonyNavigationSurface(
              translucent: true,
              child: SizedBox(
                height: 76,
                child: Row(
                  children: [
                    Expanded(
                      child: NavigationPressFeedback(
                        child: TextButton(
                          onPressed: () => taps++,
                          child: const Text('首页'),
                        ),
                      ),
                    ),
                    const Expanded(child: Text('动态')),
                    const Expanded(child: Text('我的')),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final filter = find.byType(BackdropFilter);
      expect(filter, findsOneWidget);
      expect(tester.getSize(filter), Size(width, 76));
      expect(tester.getRect(filter).bottom, 800);
      expect(
        find.ancestor(of: filter, matching: find.byType(ClipRect)),
        findsWidgets,
      );
      expect(
        find.descendant(
          of: filter,
          matching: find.byType(NavigationPressFeedback),
        ),
        findsNothing,
      );
      final renderFilter = tester.renderObject(filter);
      await tester.drag(find.byType(ListView), const Offset(0, -280));
      await tester.pumpAndSettle();
      await tester.tap(find.text('首页'));
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(tester.renderObject(filter), same(renderFilter));
      expect(tester.getSize(filter), Size(width, 76));
      expect(tester.takeException(), isNull);
      expect(tester.binding.transientCallbackCount, 0);
    }
  });
}
