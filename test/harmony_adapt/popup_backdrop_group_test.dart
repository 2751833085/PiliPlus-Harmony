import 'dart:ui' as ui;
import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Future<void> openMenuHarness(
  WidgetTester tester, {
  bool immersive = true,
  bool reducedMotion = false,
  bool highContrast = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: HarmonyTheme.apply(ThemeData.dark(), immersive: immersive),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: reducedMotion,
          highContrast: highContrast,
        ),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAnchoredMenu<int>(
              context: context,
              positionBuilder: (_, constraints) => RelativeRect.fromRect(
                const Rect.fromLTWH(30, 90, 50, 40),
                Offset.zero & constraints.biggest,
              ),
              items: [
                const PopupMenuItem(value: 0, child: Text('第一层一')),
                PopupMenuItem(
                  enabled: false,
                  child: Builder(
                    builder: (menuContext) => TextButton(
                      onPressed: () => showAnchoredMenu<int>(
                        context: menuContext,
                        positionBuilder: (_, constraints) =>
                            RelativeRect.fromRect(
                              const Rect.fromLTWH(300, 170, 50, 40),
                              Offset.zero & constraints.biggest,
                            ),
                        items: const [
                          PopupMenuItem(value: 1, child: Text('第二层一')),
                          PopupMenuItem(value: 2, child: Text('第二层二')),
                        ],
                      ),
                      child: const Text('打开子菜单'),
                    ),
                  ),
                ),
                const PopupMenuItem(value: 3, child: Text('第一层三')),
              ],
            ),
            child: const Text('打开菜单'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开菜单'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'one menu shares blur input without changing radius, sigma or tint',
    (tester) async {
      await openMenuHarness(tester);
      final filters = tester
          .widgetList<BackdropFilter>(find.byType(BackdropFilter))
          .toList();
      expect(filters, hasLength(3));
      expect(
        filters.map((filter) => filter.backdropGroupKey).toSet(),
        hasLength(1),
      );
      expect(filters.first.backdropGroupKey, isNotNull);
      for (final filter in filters) {
        expect(filter.filter, ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24));
      }
      final surfaces = tester
          .widgetList<ImmersiveSurface>(find.byType(ImmersiveSurface))
          .toList();
      expect(surfaces.first.borderRadius.topLeft, const Radius.circular(20));
      expect(surfaces.last.borderRadius.bottomRight, const Radius.circular(20));
      for (final surface in surfaces) {
        expect(surface.blurSigma, 24);
        expect(surface.color, isNull);
        expect(surface.surfaceGradient, isNull);
      }
      await tester.tap(find.text('第一层三'));
      await tester.pumpAndSettle();
      expect(find.text('第一层三'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('nested and later menus never reuse another menu backdrop key', (
    tester,
  ) async {
    await openMenuHarness(tester);
    final firstKey = tester
        .widgetList<BackdropFilter>(find.byType(BackdropFilter))
        .first
        .backdropGroupKey;
    await tester.tap(find.text('打开子菜单'));
    await tester.pumpAndSettle();
    final nested = tester
        .widgetList<BackdropFilter>(find.byType(BackdropFilter))
        .toList();
    expect(nested, hasLength(5));
    final keys = nested.map((filter) => filter.backdropGroupKey).toSet();
    expect(keys, hasLength(2));
    expect(keys, contains(firstKey));
    expect(
      nested.sublist(3).map((filter) => filter.backdropGroupKey).toSet(),
      hasLength(1),
    );
    expect(nested.last.backdropGroupKey, isNot(firstKey));
    await tester.tap(find.text('第二层二'));
    await tester.pumpAndSettle();
    expect(find.text('第一层一'), findsOneWidget);
    await tester.tap(find.text('第一层三'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('打开菜单'));
    await tester.pumpAndSettle();
    final laterKey = tester
        .widgetList<BackdropFilter>(find.byType(BackdropFilter))
        .first
        .backdropGroupKey;
    expect(laterKey, isNot(firstKey));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'grouped menu blur respects immersive, contrast and motion settings',
    (tester) async {
      for (final mode in ['off', 'reduced motion', 'high contrast']) {
        await openMenuHarness(
          tester,
          immersive: mode != 'off',
          reducedMotion: mode == 'reduced motion',
          highContrast: mode == 'high contrast',
        );
        expect(find.byType(BackdropFilter), findsNothing, reason: mode);
        await tester.tap(find.text('第一层三'));
        await tester.pumpAndSettle();
        expect(find.text('第一层三'), findsNothing);
        expect(tester.takeException(), isNull, reason: mode);
      }
    },
  );
}
