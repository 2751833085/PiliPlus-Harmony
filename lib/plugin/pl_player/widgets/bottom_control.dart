import 'package:PiliPlus/plugin/pl_player/widgets/timeline.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/common/widgets/progress_bar/audio_video_progress_bar.dart';
import 'package:PiliPlus/pages/video/controller.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/view/view.dart';
import 'package:PiliPlus/utils/extension/theme_ext.dart';
import 'package:PiliPlus/utils/feed_back.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:material_ui/material_ui.dart';
import 'package:get/get.dart';

class BottomControl extends StatelessWidget {
  const BottomControl({
    super.key,
    required this.maxWidth,
    required this.isFullScreen,
    required this.controller,
    required this.buildBottomControl,
    required this.videoDetailController,
  });

  final double maxWidth;
  final bool isFullScreen;
  final PlPlayerController controller;
  final Widget Function(Widget? progress) buildBottomControl;
  final VideoDetailController videoDetailController;

  void onDragStart(ThumbDragDetails duration) {
    feedBack();
    controller.onSeekStart(duration.seconds);
  }

  void onDragUpdate(ThumbDragDetails duration) {
    if (!controller.isFileSource && controller.showSeekPreview) {
      controller.updatePreviewIndex(duration.seconds);
    }
    controller.seekPosition.value = duration.seconds;
  }

  void onSeek(int milliseconds) {
    controller
      ..position.value = milliseconds ~/ 1000
      ..onSeekEnd()
      ..seekTo(Duration(milliseconds: milliseconds), isSeek: false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final primary = colorScheme.isLight
        ? colorScheme.inversePrimary
        : colorScheme.primary;
    final thumbGlowColor = primary.withAlpha(80);
    final bufferedBarColor = primary.withValues(alpha: 0.4);

    final compact = Pref.biliPlayerControls;
    final barHeight = compact ? 2.0 : 3.5;
    final progress = Padding(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 10)
          : const EdgeInsets.fromLTRB(10, 0, 10, 7),
      child: Obx(
        () => Offstage(
          offstage: !controller.showControls.value,
          child: PlayerTimeline(
            barHeight: barHeight,
            progress: Obx(
              () => ProgressBar(
                progress: controller.progress,
                buffered: controller.buffered.value,
                total: controller.duration.value,
                progressBarColor: primary,
                baseBarColor: const Color(0x33FFFFFF),
                bufferedBarColor: bufferedBarColor,
                thumbColor: primary,
                thumbGlowColor: thumbGlowColor,
                barHeight: barHeight,
                thumbRadius: compact ? 5 : 7,
                thumbGlowRadius: 25,
                onDragStart: onDragStart,
                onDragUpdate: onDragUpdate,
                onSeek: onSeek,
              ),
            ),
            segments: controller.enableBlock
                ? videoDetailController.segmentProgressList.toList()
                : const [],
            chapters:
                controller.showViewPoints && videoDetailController.showVP.value
                ? videoDetailController.viewPointList.toList()
                : const [],
            onChapterSeek: PlatformUtils.isDesktop
                ? (position) => controller.seekTo(position, isSeek: false)
                : null,
            trend:
                videoDetailController.showDmTrendChart.value &&
                    videoDetailController.dmTrend.value?.dataOrNull != null
                ? buildDmChart(
                    primary,
                    videoDetailController.dmTrend.value!.dataOrNull!,
                    videoDetailController,
                    (PlayerTimeline.seekHeight + barHeight) / 2 - 4.25,
                  )
                : null,
          ),
        ),
      ),
    );
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 12,
      ),
      child: compact
          ? buildBottomControl(progress)
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [progress, buildBottomControl(null)],
            ),
    );
  }
}
