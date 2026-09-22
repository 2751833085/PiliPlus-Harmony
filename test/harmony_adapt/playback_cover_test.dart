import 'package:PiliPlus/pages/video/widgets/playback_cover.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  testWidgets(
    'switching to short playback removes cover and keeps video taps reachable',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final autoplay = false.obs;
      var short = false;
      var videoTaps = 0, coverTaps = 0;
      for (final width in [1008.0, 2048.0, 3184.0]) {
        tester.view.physicalSize = Size(width, 2232);
        tester.view.devicePixelRatio = 2.875;
        Future<void> mount() => tester.pumpWidget(
          MaterialApp(
            home: Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  onTap: () => videoTaps++,
                  child: const ColoredBox(color: Colors.black),
                ),
                PlaybackCover(
                  shortMode: short,
                  autoPlay: () => autoplay.value,
                  builder: (_) => Positioned.fill(
                    child: GestureDetector(
                      onTap: () => coverTaps++,
                      child: const ColoredBox(color: Colors.blue),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        short = false;
        autoplay.value = false;
        await mount();
        await tester.tapAt(
          tester.view.physicalSize.center(Offset.zero) / 2.875,
        );
        expect(coverTaps, greaterThan(0));
        for (final playing in [false, true, false]) {
          short = true;
          autoplay.value = playing;
          await mount();
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(find.byType(ErrorWidget), findsNothing);
          final before = videoTaps;
          await tester.tapAt(
            tester.view.physicalSize.center(Offset.zero) / 2.875,
          );
          expect(videoTaps, before + 1);
        }
        short = false;
        await mount();
        final previous = coverTaps;
        await tester.tapAt(
          tester.view.physicalSize.center(Offset.zero) / 2.875,
        );
        expect(coverTaps, previous + 1);
        autoplay.value = true;
        await tester.pump();
        final previousVideo = videoTaps;
        await tester.tapAt(
          tester.view.physicalSize.center(Offset.zero) / 2.875,
        );
        expect(videoTaps, previousVideo + 1);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
      autoplay.close();
    },
  );
}
