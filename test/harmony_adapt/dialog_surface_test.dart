import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets(
    'opaque navigation finish removes backdrop blur and transmission',
    (tester) async {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: HarmonyTheme.apply(
              ThemeData(brightness: brightness),
              immersive: true,
            ),
            home: const Scaffold(
              body: ImmersiveSurface(
                opaque: true,
                blurBackground: true,
                child: SizedBox(width: 400, height: 60),
              ),
            ),
          ),
        );
        expect(find.byType(BackdropFilter), findsNothing);
        final gradients = tester
            .widgetList<DecoratedBox>(find.byType(DecoratedBox))
            .map((box) => box.decoration)
            .whereType<BoxDecoration>()
            .map((box) => box.gradient)
            .whereType<LinearGradient>();
        expect(gradients, isNotEmpty);
        for (final gradient in gradients) {
          expect(gradient.colors.every((color) => color.a == 1), isTrue);
        }
        expect(find.byType(ImmersiveInteraction), findsOneWidget);
      }
    },
  );

  testWidgets('immersive dialog preserves cancel, confirmation and result', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: HarmonyTheme.apply(ThemeData.dark(), immersive: true),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              child: const Text('Open'),
              onPressed: () async {
                result = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Confirm'),
                    content: const Text('Keep existing data'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Continue'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(
      find.ancestor(
        of: find.text('Keep existing data'),
        matching: find.byType(ImmersiveSurface),
      ),
      findsWidgets,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, false);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(result, true);
    expect(tester.takeException(), isNull);
    expect(tester.binding.transientCallbackCount, 0);
  });
}
