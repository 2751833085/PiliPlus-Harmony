import 'package:PiliPlus/pages/video/shorts/metrics.dart';
import 'package:flutter/material.dart';

/// Fades only the controls; video geometry and its decoder stay untouched.
class ShortVideoChrome extends StatelessWidget {
  const ShortVideoChrome({
    super.key,
    required this.visible,
    required this.child,
  });
  final bool visible;
  final Widget child;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !visible,
    child: ExcludeSemantics(
      excluding: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        child: child,
      ),
    ),
  );
}

/// Pausing preserves the information layer and offers a central resume target.
/// Only the button captures taps; gestures elsewhere still reach the player.
class ShortVideoPausedControls extends StatelessWidget {
  const ShortVideoPausedControls({
    super.key,
    required this.time,
    required this.onResume,
    this.compact = false,
  });
  final String time;
  final VoidCallback onResume;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final metrics = ShortVideoMetrics.of(context);
    final button = Semantics(
      button: true,
      label: '继续播放',
      child: Tooltip(
        message: '继续播放',
        child: GestureDetector(
          onTap: onResume,
          child: Container(
            width: compact ? metrics.controlHeight : metrics.pauseButton,
            height: compact ? metrics.controlHeight : metrics.pauseButton,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .24),
              borderRadius: BorderRadius.circular(compact ? 14 : 18),
            ),
            child: Icon(
              Icons.play_arrow_rounded,
              color: Colors.white.withValues(alpha: .75),
              size: compact ? metrics.icon : metrics.icon + 12,
            ),
          ),
        ),
      ),
    );
    final timestamp = IgnorePointer(
      child: Text(
        time,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: ShortVideoMetrics.time,
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ShortVideoMetrics.informationRight,
      ),
      child: compact
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                button,
                const SizedBox(width: 12),
                Flexible(child: timestamp),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [button, const SizedBox(height: 12), timestamp],
            ),
    );
  }
}

/// Full-width scrubber stays fixed. Minimal mode reveals playback and time
/// immediately above it, matching the reference without moving the video.
class ShortVideoMinimalControls extends StatelessWidget {
  const ShortVideoMinimalControls({
    super.key,
    required this.playing,
    required this.time,
    required this.progress,
    required this.onToggle,
    this.showPlayback = true,
    this.seeking = false,
  });
  final bool playing, showPlayback, seeking;
  final String time;
  final Widget progress;
  final VoidCallback onToggle;
  static double heightFor(TextScaler scaler) =>
      ShortVideoMetrics(scaler).playbackHeight;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: heightFor(MediaQuery.textScalerOf(context)),
    child: Column(
      children: [
        Expanded(
          child: ShortVideoChrome(
            visible: showPlayback || seeking,
            child: seeking
                ? Center(
                    child: Text(
                      time,
                      style: ShortVideoMetrics.time,
                    ),
                  )
                : Row(
                    children: [
                      Tooltip(
                        message: playing ? '暂停' : '播放',
                        child: Semantics(
                          button: true,
                          label: playing ? '暂停' : '播放',
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: onToggle,
                            onDoubleTap: onToggle,
                            child: SizedBox.square(
                              dimension: ShortVideoMetrics.touchWidth,
                              child: Icon(
                                playing
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                size: ShortVideoMetrics.of(context).icon,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          time,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ShortVideoMetrics.time,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        SizedBox(height: ShortVideoMetrics.seekTarget, child: progress),
      ],
    ),
  );
}
