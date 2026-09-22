import 'package:flutter/material.dart';

/// Current position and duration share one baseline, including hour-long media.
class PlayerControlTime extends StatelessWidget {
  const PlayerControlTime({
    super.key,
    required this.position,
    required this.duration,
  });
  final String position, duration;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(text: position),
        TextSpan(
          text: ' / $duration',
          style: const TextStyle(color: Color(0xFFD0D0D0)),
        ),
      ],
    ),
    maxLines: 1,
    softWrap: false,
    textDirection: TextDirection.ltr,
    semanticsLabel: '当前时间 $position，总时长 $duration',
    style: const TextStyle(
      color: Colors.white,
      fontSize: 13,
      height: 1.25,
      fontFeatures: [FontFeature.tabularFigures()],
    ),
  );
}

/// Only the seek track expands. Time no longer reserves half the control bar.
class CompactPlayerControlBar extends StatelessWidget {
  const CompactPlayerControlBar({
    super.key,
    required this.play,
    required this.progress,
    required this.time,
    required this.actions,
  });
  final Widget play, progress, time;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      // Reserve a usable track even on a folded phone. Long time strings
      // scale within their own budget, without creating a second control row.
      return Row(
        children: [
          play,
          Expanded(child: progress),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: bounds.maxWidth * (bounds.maxWidth < 400 ? .24 : .32),
            ),
            child: FittedBox(fit: BoxFit.scaleDown, child: time),
          ),
          ...actions,
        ],
      );
    },
  );
}
