import 'package:PiliPlus/common/widgets/progress_bar/audio_video_progress_bar.dart';
import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:PiliPlus/pages/video/shorts/controls.dart';
import 'package:PiliPlus/pages/video/shorts/metrics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'footer keeps its proportions across app themes and respects large text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      var sends = 0;
      final regularTheme = ThemeData();
      final harmonyTheme = HarmonyTheme.apply(regularTheme);
      final oversizedButtons = harmonyTheme.copyWith(
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            textStyle: const TextStyle(fontSize: 30, height: 2),
            padding: const EdgeInsets.all(30),
            minimumSize: const Size(100, 100),
          ),
        ),
      );
      Rect? previousInput;
      double? previousTextHeight;
      for (final scale in [1.0, 1.3, 2.0]) {
        Rect? baseInput;
        Size? baseText;
        for (final theme in [regularTheme, harmonyTheme, oversizedButtons]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: MediaQuery(
                data: MediaQueryData(
                  size: const Size(390, 844),
                  textScaler: TextScaler.linear(scale),
                ),
                child: Scaffold(
                  body: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ShortVideoControls(
                        danmaku: true,
                        onSend: () => sends++,
                        onDanmaku: () {},
                        onDanmakuSettings: () {},
                        onDetails: () {},
                        onFullscreen: () {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final input = tester.getRect(
            find.byKey(const ValueKey('short-danmaku-input')),
          );
          final text = tester.getRect(find.text('发弹幕'));
          final rich = tester.renderObject<RenderParagraph>(
            find.descendant(
              of: find.text('发弹幕'),
              matching: find.byType(RichText),
            ),
          );
          expect(rich.didExceedMaxLines, false);
          expect(input.contains(text.topLeft), true);
          expect(input.contains(text.bottomRight), true);
          expect(input.height, greaterThanOrEqualTo(44));
          expect(input.width, lessThanOrEqualTo(200));
          baseInput ??= input;
          baseText ??= text.size;
          expect(input, baseInput);
          expect(text.size, baseText);
          // The transparent margin around the capsule is also interactive.
          await tester.tapAt(Offset(input.center.dx, input.top + 1));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        if (previousInput != null) {
          expect(baseInput!.height, greaterThanOrEqualTo(previousInput.height));
          expect(baseText!.height, greaterThan(previousTextHeight!));
        }
        previousInput = baseInput;
        previousTextHeight = baseText!.height;
      }
      expect(sends, 9);
    },
  );

  testWidgets(
    'seek track stays centered as thumb grows; natural sizing remains unchanged',
    (tester) async {
      for (final targetHeight in <double?>[null, 28]) {
        for (final seeking in [false, true]) {
          final barHeight = seeking
              ? ShortVideoMetrics.activeTrack
              : ShortVideoMetrics.track;
          final radius = seeking
              ? ShortVideoMetrics.activeThumb
              : ShortVideoMetrics.thumb;
          await tester.pumpWidget(
            MaterialApp(
              home: Center(
                child: SizedBox(
                  width: 200,
                  height: targetHeight,
                  child: ProgressBar(
                    progress: 25,
                    total: 100,
                    barHeight: barHeight,
                    thumbRadius: radius,
                    baseBarColor: Colors.grey,
                    progressBarColor: Colors.pink,
                    bufferedBarColor: Colors.blue,
                    thumbColor: Colors.white,
                    thumbGlowColor: Colors.white12,
                  ),
                ),
              ),
            ),
          );
          final bar = find.byType(ProgressBar);
          final height = targetHeight ?? radius * 2;
          expect(tester.getSize(bar).height, height);
          expect(
            tester.renderObject(bar),
            paints
              ..line(
                p1: Offset(barHeight / 2, height / 2),
                p2: Offset(200 - barHeight / 2, height / 2),
              )
              ..circle(y: height / 2, radius: radius),
          );
        }
      }
    },
  );
}
