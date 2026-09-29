import 'package:PiliPlus/common/widgets/progress_bar/audio_video_progress_bar.dart';
import 'package:PiliPlus/plugin/pl_player/widgets/app_bar_ani.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final removeSafeArea in [false, true]) {
    testWidgets(
      'fullscreen seek avoids system edges and owns drag; removeSafeArea=$removeSafeArea',
      (tester) async {
        final animation = AnimationController(
          vsync: tester,
          value: 1,
          duration: const Duration(milliseconds: 200),
        );
        addTearDown(animation.dispose);
        var videoGestures = 0;
        var seekStarts = 0;
        final seeks = <int>[];
        const track = ValueKey('seek-track');
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(800, 600),
                viewPadding: EdgeInsets.only(left: 30, bottom: 10),
                systemGestureInsets: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  bottom: 32,
                ),
              ),
              child: Scaffold(
                body: Stack(
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: (_) => videoGestures++,
                        onTap: () => videoGestures++,
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: AppBarAni(
                        controller: animation,
                        isTop: false,
                        isFullScreen: true,
                        removeSafeArea: removeSafeArea,
                        fadeOnly: true,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: SizedBox(
                            key: track,
                            height: 28,
                            child: ProgressBar(
                              progress: 30,
                              total: 300,
                              baseBarColor: Colors.white24,
                              progressBarColor: Colors.pink,
                              bufferedBarColor: Colors.white38,
                              thumbColor: Colors.white,
                              thumbGlowColor: Colors.white12,
                              onDragStart: (_) => seekStarts++,
                              onSeek: seeks.add,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        final bounds = tester.getRect(find.byKey(track));
        expect(bounds.bottom, lessThanOrEqualTo(600 - 32 - 8));
        expect(bounds.left, greaterThanOrEqualTo(removeSafeArea ? 20 : 30));
        expect(bounds.right, lessThanOrEqualTo(800 - 20));
        final gesture = await tester.startGesture(
          Offset(bounds.left + 40, bounds.center.dy),
        );
        await gesture.moveBy(const Offset(120, -8));
        await gesture.moveBy(const Offset(80, 18));
        await gesture.up();
        await tester.pump();
        expect(seekStarts, 1);
        expect(seeks, hasLength(1));
        expect(seeks.single, greaterThan(0));
        expect(videoGestures, 0);
        // The small padded gap around the track must not pass through.
        await tester.dragFrom(
          Offset(bounds.left + 80, bounds.top - 5),
          const Offset(70, -10),
        );
        expect(videoGestures, 0);
        await tester.tapAt(const Offset(400, 200));
        expect(videoGestures, 1, reason: 'gestures on the picture still work');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
