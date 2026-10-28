import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/pages/video/widgets/tablet_video_sidebar.dart';

void main() {
  test('new comment placement is limited to enabled dual-fold windows', () {
    for (final size in [const Size(712, 776), const Size(776, 712)]) {
      expect(
        TabletVideoLayout.commentsBelowVideo(
          size,
          foldable: true,
          enabled: true,
        ),
        isTrue,
      );
      expect(
        TabletVideoLayout.commentsBelowVideo(
          size,
          foldable: true,
          enabled: false,
        ),
        isFalse,
        reason:
            'Turning it off leaves the existing combined/info preferences in charge',
      );
      expect(
        TabletVideoLayout.commentsBelowVideo(
          size,
          foldable: false,
          enabled: true,
        ),
        isFalse,
        reason: 'The preference is unavailable on an ordinary square tablet',
      );
    }
    for (final size in [
      const Size(350, 776),
      const Size(1108, 776),
      const Size(776, 1108),
      const Size(712, 480),
    ]) {
      expect(
        TabletVideoLayout.commentsBelowVideo(
          size,
          foldable: true,
          enabled: true,
        ),
        isFalse,
      );
      expect(TabletVideoLayout.playerAspectRatio(size, foldable: true), 16 / 9);
    }
  });

  test(
    'UI zoom cannot turn a triple fold into a double fold or vice versa',
    () {
      for (final unscaled in [const Size(1108, 776), const Size(776, 1108)]) {
        expect(
          TabletVideoLayout.commentsBelowVideo(
            unscaled / 1.2,
            unscaledWindow: unscaled,
            foldable: true,
            enabled: true,
          ),
          isFalse,
        );
        expect(
          TabletVideoLayout.playerAspectRatio(
            unscaled / 1.2,
            unscaledWindow: unscaled,
            foldable: true,
          ),
          16 / 9,
        );
      }
      const single = Size(350, 776);
      expect(
        TabletVideoLayout.commentsBelowVideo(
          single / .5,
          unscaledWindow: single,
          foldable: true,
          enabled: true,
        ),
        isFalse,
        reason:
            'UI zoom must not make a one-panel phone look like a double fold',
      );
      const dual = Size(712, 776);
      for (final scale in [.8, 1.0]) {
        expect(
          TabletVideoLayout.commentsBelowVideo(
            dual / scale,
            unscaledWindow: dual,
            foldable: true,
            enabled: true,
          ),
          isTrue,
        );
      }
      expect(
        TabletVideoLayout.commentsBelowVideo(
          dual / 1.1,
          unscaledWindow: dual,
          foldable: true,
          enabled: true,
        ),
        isFalse,
        reason:
            'Keep the existing minimum readable canvas width at higher UI zoom',
      );
    },
  );

  test(
    'dual-fold player gains a little height without changing column widths',
    () {
      for (final size in [const Size(712, 776), const Size(776, 712)]) {
        final leftWidth =
            size.width - TabletVideoLayout.sidebarWidth(size.width);
        final height =
            leftWidth /
            TabletVideoLayout.playerAspectRatio(size, foldable: true);
        final previousHeight = leftWidth / (16 / 9);
        expect(height / previousHeight, inInclusiveRange(1.05, 1.07));
        expect(height, lessThan(size.height / 2));
        expect(
          TabletVideoLayout.sidebarWidth(size.width) / size.width,
          closeTo(.365, .001),
        );
      }
    },
  );
}
