import 'package:flutter/widgets.dart';

/// Collapse neighbouring panels without relaying out their text every frame.
/// The player itself keeps one element/decoder and receives the animated bounds.
class PlayerExpansionPanel extends StatelessWidget {
  const PlayerExpansionPanel({
    super.key,
    required this.progress,
    required this.axis,
    required this.child,
  });

  final double progress;
  final Axis axis;
  final Widget child;

  @override
  Widget build(BuildContext context) => Offstage(
    offstage: progress >= 1,
    child: ClipRect(
      child: Align(
        alignment: Alignment.topLeft,
        widthFactor: axis == Axis.horizontal ? 1 - progress : 1,
        heightFactor: axis == Axis.vertical ? 1 - progress : 1,
        child: child,
      ),
    ),
  );
}

double expandedPlayerExtent(double inline, double full, double progress) =>
    inline + (full - inline) * progress.clamp(0.0, 1.0);
