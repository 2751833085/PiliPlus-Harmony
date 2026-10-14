import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/common/widgets/image/full_cover_preview.dart';

void main() {
  for (final size in [
    const Size(1600, 900),
    const Size(900, 1600),
    const Size(1000, 1000),
  ]) {
    testWidgets('full cover preserves entire $size within viewport', (
      tester,
    ) async {
      final bytes = await tester.runAsync(() async {
        final image = await createTestImage(
          width: size.width.toInt(),
          height: size.height.toInt(),
        );
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        return data!.buffer.asUint8List();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: FullCoverPreview(
              image: MemoryImage(bytes!),
              width: 480,
              aspectRatio: size.aspectRatio,
              maxHeight: 500,
            ),
          ),
        ),
      );
      final before = tester.getSize(find.byType(RawImage));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pumpAndSettle();
      final render = tester.renderObject<RenderImage>(find.byType(RawImage));
      expect(render.image, isNotNull);
      expect(
        render.size,
        before,
      ); // first frame must never change preview geometry
      final fitted = applyBoxFit(render.fit!, size, render.size);
      expect(fitted.source, size); // no cropping, including tall covers
      expect(render.size.height, lessThanOrEqualTo(500));
      expect(tester.takeException(), isNull);
    });
  }
}
