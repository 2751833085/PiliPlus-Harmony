import 'package:PiliPlus/common/style.dart';
import 'dart:ui' as ui;
import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:PiliPlus/pages/video/shorts/comments_layout.dart';
import 'package:PiliPlus/pages/video/shorts/metrics.dart';
import 'package:PiliPlus/pages/video/shorts/controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' as m;

void main() {
  Future<void> corners(
    WidgetTester tester,
    GlobalKey capture,
    Rect rect,
    double dpr, {
    bool topOnly = false,
    Offset? contentPoint,
  }) async {
    final boundary =
        capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = (await tester.runAsync(
      () => boundary.toImage(pixelRatio: dpr),
    ))!;
    final data = (await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
    ))!;
    Color pixel(Offset p) {
      final i = ((p.dy * dpr).floor() * image.width + (p.dx * dpr).floor()) * 4;
      return Color.fromARGB(
        data.getUint8(i + 3),
        data.getUint8(i),
        data.getUint8(i + 1),
        data.getUint8(i + 2),
      );
    }

    for (final p in [
      rect.topLeft + const Offset(1, 1),
      rect.topRight + const Offset(-1, 1),
      if (!topOnly) rect.bottomLeft + const Offset(1, -1),
      if (!topOnly) rect.bottomRight - const Offset(1, 1),
    ]) {
      final c = pixel(p);
      // Background/barrier is black. A colored child must not square off a corner.
      expect(
        c.r + c.g + c.b,
        lessThan(.12),
        reason: 'unclipped corner at $p: $c',
      );
    }
    expect(
      pixel(contentPoint ?? rect.center).g,
      greaterThan(.3),
      reason:
          'center $rect boundary ${boundary.size} offset ${boundary.localToGlobal(Offset.zero)}',
    );
    image.dispose();
  }

  testWidgets(
    'comments have four clipped corners on native phone and triple viewports',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final size in [const Size(1008, 2232), const Size(3184, 2232)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 2.875;
        final capture = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            home: RepaintBoundary(
              key: capture,
              child: Scaffold(
                backgroundColor: Colors.black,
                body: ShortCommentsLayout(
                  panel: const ColoredBox(
                    key: ValueKey('panel'),
                    color: Colors.green,
                  ),
                  builder: (_, compact) =>
                      const ColoredBox(color: Colors.black),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await corners(
          tester,
          capture,
          tester.getRect(find.byKey(const ValueKey('panel'))),
          2.875,
        );
      }
    },
  );
  testWidgets(
    'Harmony sheets dialogs and immersive menus clip colored children at every corner',
    (tester) async {
      tester.view.physicalSize = const Size(3184, 2232);
      tester.view.devicePixelRatio = 2.875;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final theme in [
        ThemeData.dark().copyWith(
          bottomSheetTheme: const BottomSheetThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: Style.bottomSheetRadius,
            ),
            clipBehavior: Clip.antiAlias,
          ),
          dialogTheme: const DialogThemeData(clipBehavior: Clip.antiAlias),
          popupMenuTheme: const PopupMenuThemeData(
            menuPadding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: Style.bottomSheetRadius,
            ),
          ),
        ),
        HarmonyTheme.apply(ThemeData.dark()),
        HarmonyTheme.apply(ThemeData.dark(), immersive: true),
      ]) {
        final capture = GlobalKey();
        late BuildContext page;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            builder: (_, child) => RepaintBoundary(key: capture, child: child!),
            home: Builder(
              builder: (context) {
                page = context;
                return const Scaffold(backgroundColor: Colors.black);
              },
            ),
          ),
        );
        showModalBottomSheet<void>(
          context: page,
          builder: (_) => const SizedBox(
            height: 220,
            width: double.infinity,
            child: ColoredBox(key: ValueKey('sheet'), color: Colors.green),
          ),
        );
        await tester.pumpAndSettle();
        await corners(
          tester,
          capture,
          tester.getRect(find.byKey(const ValueKey('sheet'))),
          2.875,
        );
        Navigator.pop(page);
        await tester.pumpAndSettle();
        showDialog<void>(
          context: page,
          builder: (_) => const Dialog(
            child: SizedBox(
              height: 180,
              width: 400,
              child: ColoredBox(key: ValueKey('dialog'), color: Colors.green),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await corners(
          tester,
          capture,
          tester.getRect(find.byKey(const ValueKey('dialog'))),
          2.875,
        );
        Navigator.pop(page);
        await tester.pumpAndSettle();
        final result = m.showMenu<int>(
          constraints: const BoxConstraints.tightFor(width: 200),
          context: page,
          position: const RelativeRect.fromLTRB(100, 100, 300, 300),
          items: [
            const PopupMenuItem(
              value: 1,
              padding: EdgeInsets.zero,
              child: SizedBox(
                width: 200,
                height: 96,
                child: ColoredBox(key: ValueKey('menu'), color: Colors.green),
              ),
            ),
          ],
        );
        await tester.pumpAndSettle();
        await corners(
          tester,
          capture,
          tester.getRect(
            find.byType(m.ImmersiveSurface).evaluate().isNotEmpty
                ? find.byType(m.ImmersiveSurface)
                : find.byKey(const ValueKey('menu')),
          ),
          2.875,
          topOnly: theme.extension<m.PopupSheetStyle>() != null,
          contentPoint: tester.getCenter(find.byKey(const ValueKey('menu'))),
        );
        await tester.tap(find.byKey(const ValueKey('menu')));
        await tester.pumpAndSettle();
        expect(await result, 1);
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'capsule press stays clipped while its 44dp target and context link work',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: Column(
              children: [
                SizedBox(
                  width: 180,
                  child: ShortVideoPillButton(
                    label: '发弹幕',
                    onPressed: () => taps++,
                  ),
                ),
                ShortVideoContextLink(
                  icon: Icons.search,
                  label: '搜索',
                  onTap: () => taps++,
                ),
              ],
            ),
          ),
        ),
      );
      final pill = find.byType(ShortVideoPillButton);
      final target = tester.getRect(pill);
      final material = tester.widget<Material>(
        find.descendant(of: pill, matching: find.byType(Material)),
      );
      expect(material.shape, isA<StadiumBorder>());
      expect(material.clipBehavior, Clip.antiAlias);
      await tester.tapAt(target.topCenter + const Offset(0, 1));
      await tester.pump();
      await tester.tap(find.text('发弹幕'));
      await tester.pump();
      await tester.tap(find.text('搜索'));
      await tester.pump();
      expect(taps, 3);
      expect(target.height, greaterThanOrEqualTo(44));
    },
  );
}
