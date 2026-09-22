import 'package:flutter/material.dart';
import 'package:PiliPlus/common/widgets/progress_bar/segment_progress_bar.dart';

/// A single baseline for seeking, SponsorBlock segments and chapter boundaries.
/// Decorative overlays never intercept the seek track's hit area.
class PlayerTimeline extends StatelessWidget {
  const PlayerTimeline({
    super.key,
    required this.progress,
    required this.barHeight,
    this.segments = const [],
    this.chapters = const [],
    this.onChapterSeek,
    this.trend,
  });
  static const seekHeight = 28.0;
  final Widget progress;
  final double barHeight;
  final List<Segment> segments;
  final List<ViewPointSegment> chapters;
  final ValueChanged<Duration>? onChapterSeek;

  /// Includes its own margin above the track and chapters.
  final Widget? trend;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: seekHeight + (chapters.isEmpty ? 0 : 15) + (trend == null ? 0 : 12),
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: seekHeight,
          child: progress,
        ),
        if (segments.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: (seekHeight - barHeight) / 2,
            child: IgnorePointer(
              child: SegmentProgressBar(height: barHeight, segments: segments),
            ),
          ),
        if (chapters.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: (seekHeight + barHeight) / 2,
            child: ViewPointSegmentProgressBar(
              height: barHeight,
              segments: chapters,
              onSeek: onChapterSeek,
              fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
              fontWeight: Theme.of(context).textTheme.bodyMedium?.fontWeight,
            ),
          ),
        if (trend != null)
          Positioned(left: 0, right: 0, bottom: 0, child: trend!),
      ],
    ),
  );
}
