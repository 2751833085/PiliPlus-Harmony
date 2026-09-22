import 'package:PiliPlus/common/widgets/progress_bar/audio_video_progress_bar.dart';
import 'package:PiliPlus/harmony_adapt/harmony_channel.dart';
import 'package:PiliPlus/pages/video/shorts/controls.dart';
import 'package:PiliPlus/plugin/pl_player/widgets/app_bar_ani.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    HarmonyChannel.cutoutInsets.value = EdgeInsets.zero;
    HarmonyChannel.decorTopInset.value = 0;
  });

  test(
    'cutouts merge per edge without double counting system bars or UI scale',
    () {
      HarmonyChannel.cutoutInsets.value = const EdgeInsets.fromLTRB(
        138,
        115,
        0,
        0,
      );
      HarmonyChannel.decorTopInset.value = 172.5;
      const system = EdgeInsets.fromLTRB(8, 48, 0, 24);
      expect(
        HarmonyChannel.mergeCutout(system, 2.875),
        const EdgeInsets.fromLTRB(48, 60, 0, 24),
      );
      for (final scale in [.8, 1.0, 1.3]) {
        final scaled = HarmonyChannel.mergeCutout(system, 2.875) / scale;
        final actual = HarmonyChannel.mergeCutout(
          system / scale,
          2.875 * scale,
        );
        expect(actual.left, closeTo(scaled.left, 0.00001));
        expect(actual.top, closeTo(scaled.top, 0.00001));
        expect(actual.bottom, closeTo(scaled.bottom, 0.00001));
      }
      // A viewer's preserved top inset must not erase a newly rotated cutout.
      HarmonyChannel.decorTopInset.value = 0;
      HarmonyChannel.cutoutInsets.value = const EdgeInsets.only(right: 138);
      expect(HarmonyChannel.mergeCutout(system, 2.875).right, 48);
      HarmonyChannel.cutoutInsets.value = EdgeInsets.zero;
      expect(HarmonyChannel.mergeCutout(system, 2.875), system);
    },
  );

  testWidgets(
    'player controls remain clickable outside cutouts and gesture area across native pixel profiles',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final animation = AnimationController(vsync: tester, value: 1);
      addTearDown(animation.dispose);
      var back = 0, details = 0, sends = 0, seeks = 0;
      // Only the triple DPR was measured on-device. Other forms/orientations and
      // cutout positions below are synthetic stress cases, not hardware captures.
      for (final pixels in [
        const Size(1008, 2232),
        const Size(2048, 2232),
        const Size(3184, 2232),
      ]) {
        for (final rotate in [false, true]) {
          final physical = rotate ? Size(pixels.height, pixels.width) : pixels;
          tester.view.physicalSize = physical;
          tester.view.devicePixelRatio = 2.875;
          for (final scale in [1.0, 2.0]) {
            for (final edge in [0, 1, 2]) {
              HarmonyChannel.cutoutInsets.value = EdgeInsets.fromLTRB(
                edge == 1 ? 138 : 0,
                edge == 0 ? 115 : 0,
                edge == 2 ? 138 : 0,
                0,
              );
              final safe = HarmonyChannel.mergeCutout(
                const EdgeInsets.only(bottom: 24),
                2.875,
              );
              final size = physical / 2.875;
              await tester.pumpWidget(
                MaterialApp(
                  home: MediaQuery(
                    data: MediaQueryData(
                      size: size,
                      devicePixelRatio: 2.875,
                      padding: safe,
                      viewPadding: safe,
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: Scaffold(
                      backgroundColor: Colors.black,
                      body: Stack(
                        children: [
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: AppBarAni(
                              controller: animation,
                              isTop: true,
                              isFullScreen: true,
                              removeSafeArea: false,
                              topInset: safe.top,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: IconButton(
                                  key: const ValueKey('back'),
                                  onPressed: () => back++,
                                  icon: const Icon(Icons.arrow_back),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: AppBarAni(
                              controller: animation,
                              isTop: false,
                              isFullScreen: true,
                              removeSafeArea: false,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      height: 28,
                                      child: ProgressBar(
                                        progress: 30,
                                        total: 300,
                                        baseBarColor: Colors.white24,
                                        progressBarColor: Colors.pink,
                                        bufferedBarColor: Colors.white38,
                                        thumbColor: Colors.white,
                                        thumbGlowColor: Colors.white12,
                                        onDragStart: (_) {},
                                        onSeek: (_) => seeks++,
                                      ),
                                    ),
                                    ShortVideoControls(
                                      danmaku: true,
                                      onSend: () => sends++,
                                      onDanmaku: () {},
                                      onDanmakuSettings: () {},
                                      onDetails: () => details++,
                                      onFullscreen: () {},
                                    ),
                                  ],
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
              await tester.pumpAndSettle();
              final safeRect = Rect.fromLTRB(
                safe.left,
                safe.top,
                size.width - safe.right,
                size.height - safe.bottom,
              );
              for (final finder in [
                find.byKey(const ValueKey('back')),
                find.byTooltip('普通详情'),
                find.byKey(const ValueKey('short-danmaku-input')),
                find.byType(ProgressBar),
              ]) {
                final rect = tester.getRect(finder);
                // A landscape top cutout is intentionally included: controls
                // should avoid it even if the device reports it on this edge.
                expect(rect.left, greaterThanOrEqualTo(safeRect.left));
                expect(rect.right, lessThanOrEqualTo(safeRect.right + .01));
                expect(rect.top, greaterThanOrEqualTo(safeRect.top));
                expect(rect.bottom, lessThanOrEqualTo(safeRect.bottom + .01));
                await tester.tap(finder);
                await tester.pump();
              }
              final track = tester.getRect(find.byType(ProgressBar));
              final footer = tester.getRect(find.byType(ShortVideoControls));
              expect(track.bottom, lessThanOrEqualTo(footer.top));
              expect(
                tester.takeException(),
                isNull,
                reason: '$physical text=$scale edge=$edge',
              );
            }
          }
        }
      }
      expect(back, 36);
      expect(details, 36);
      expect(sends, 36);
      expect(seeks, 36);
    },
  );
}
