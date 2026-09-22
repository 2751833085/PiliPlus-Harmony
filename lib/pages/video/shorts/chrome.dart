import 'dart:math' as math;
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
    final button = Semantics(
      button: true,
      label: '继续播放',
      child: Tooltip(
        message: '继续播放',
        child: GestureDetector(
          onTap: onResume,
          child: Container(
            width: compact ? 48 : 64,
            height: compact ? 48 : 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .24),
              borderRadius: BorderRadius.circular(compact ? 14 : 18),
            ),
            child: Icon(
              Icons.play_arrow_rounded,
              color: Colors.white.withValues(alpha: .75),
              size: compact ? 36 : 48,
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
        style: TextStyle(
          color: Colors.white,
          fontSize: compact ? 14 : 16,
          fontWeight: FontWeight.w600,
          shadows: const [Shadow(color: Colors.black87, blurRadius: 6)],
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 68),
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
              children: [button, const SizedBox(height: 16), timestamp],
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
      24 + math.max(48, scaler.scale(14) * 1.3);

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
                      style: const TextStyle(color: Colors.white, fontSize: 18),
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
                              dimension: 48,
                              child: Icon(
                                playing
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                size: 28,
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
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 6),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        SizedBox(height: 24, child: Center(child: progress)),
      ],
    ),
  );
}
