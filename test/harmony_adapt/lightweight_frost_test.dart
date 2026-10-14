import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';

void main() {
  testWidgets(
    'navigation frost is bounded and feedback does not move controls',
    (tester) async {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: HarmonyTheme.apply(
              ThemeData(brightness: brightness),
              immersive: true,
            ),
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: ImmersiveSurface(
                  blurBackground: true,
                  blurSigma: 8,
                  borderRadius: BorderRadius.zero,
                  child: const SizedBox(
                    key: ValueKey('bar'),
                    width: 600,
                    height: 56,
                  ),
                ),
              ),
            ),
          ),
        );
        final before = tester.getRect(find.byKey(const ValueKey('bar')));
        expect(
          tester.getSize(find.byType(BackdropFilter)),
          const Size(600, 56),
        );
        final gesture = await tester.startGesture(before.center);
        await gesture.moveBy(const Offset(15, 0));
        await tester.pump();
        expect(tester.getRect(find.byKey(const ValueKey('bar'))), before);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(tester.binding.transientCallbackCount, 0);
      }
    },
  );
}
