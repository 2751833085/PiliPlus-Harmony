import 'package:PiliPlus/pages/video/reply/widgets/panel_header.dart';
import 'package:PiliPlus/pages/video/shorts/panel_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('comment surface resets inherited $brightness typography', (
      tester,
    ) async {
      final base = ThemeData(brightness: brightness);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Material(
            child: ShortVideoPanelSurface(
              base: base,
              child: const Text('评论正文'),
            ),
          ),
        ),
      );
      final richText = tester.widget<RichText>(
        find.descendant(of: find.text('评论正文'), matching: find.byType(RichText)),
      );
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(ShortVideoPanelSurface),
          matching: find.byType(Material),
        ),
      );
      final scheme = shortVideoPanelTheme(base).colorScheme;
      expect(richText.text.style!.color, scheme.onSurface);
      expect(material.color, scheme.surface);
    });
  }
  testWidgets('dark comment title stays readable inside a light app Material', (
    tester,
  ) async {
    final panelTheme = shortVideoPanelTheme(ThemeData.dark());
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Material(
          child: Theme(
            data: panelTheme,
            child: Center(
              child: ReplyPanelHeader(
                title: '评论 (9)',
                sortLabel: '最热',
                onSort: () {},
                onClose: () {},
              ),
            ),
          ),
        ),
      ),
    );
    final renderedTitle = tester.widget<RichText>(
      find.descendant(of: find.text('评论 (9)'), matching: find.byType(RichText)),
    );
    final foreground = renderedTitle.text.style!.color!.computeLuminance();
    final background = panelTheme.colorScheme.surface.computeLuminance();
    final contrast = foreground > background
        ? (foreground + .05) / (background + .05)
        : (background + .05) / (foreground + .05);
    expect(contrast, greaterThanOrEqualTo(4.5));
    expect(tester.takeException(), isNull);
  });
}
