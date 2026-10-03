import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/common/skeleton/video_card_h.dart';
import 'package:PiliPlus/common/style.dart';

void main() {
  testWidgets(
    'sidebar placeholders retain cover ratio and fit narrow and wide panes',
    (tester) async {
      for (final width in [260.0, 320.0, 440.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox(
                width: width,
                height: 110,
                child: const VideoCardHSkeleton(adaptiveCover: true),
              ),
            ),
          ),
        );
        final cover = tester.getSize(find.byType(AspectRatio));
        expect(cover.width / cover.height, closeTo(Style.aspectRatio, .001));
        expect(cover.width, lessThan(width / 2));
        expect(cover.height, lessThanOrEqualTo(100));
        await tester.pump(const Duration(milliseconds: 120));
        expect(tester.getSize(find.byType(AspectRatio)), cover);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
}
