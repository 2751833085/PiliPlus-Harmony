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
