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

/// Persistent playback row. The information layer can fade independently.
class ShortVideoMinimalControls extends StatelessWidget {
  const ShortVideoMinimalControls({
    super.key,
    required this.playing,
    required this.time,
    required this.progress,
    required this.onToggle,
  });
  final bool playing;
  final String time;
  final Widget progress;
  final VoidCallback onToggle;
  static double heightFor(TextScaler scaler) =>
      math.max(48, 24 + scaler.scale(12) * 1.3);

  @override
  Widget build(BuildContext context) => SizedBox(
    height: heightFor(MediaQuery.textScalerOf(context)),
    child: Row(
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
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 28,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: 24, child: Center(child: progress)),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  time,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    color: Colors.white70,
                    shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
