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

class ShortVideoMinimalControls extends StatelessWidget {
  const ShortVideoMinimalControls({
    super.key,
    required this.playing,
    required this.time,
    required this.onToggle,
  });
  final bool playing;
  final String time;
  final VoidCallback onToggle;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: playing ? '暂停' : '播放',
          child: GestureDetector(
            onTap: onToggle,
            onDoubleTap: onToggle,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 48,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        if (time.isNotEmpty) const SizedBox(height: 12),
        if (time.isNotEmpty)
          IgnorePointer(
            child: Text(
              time,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
                shadows: [Shadow(color: Colors.black, blurRadius: 6)],
              ),
            ),
          ),
      ],
    ),
  );
}
