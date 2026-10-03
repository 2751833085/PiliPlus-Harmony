import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';

abstract final class EpisodeLayout {
  static double coverWidth(double width) => (width * .34).clamp(80.0, 136.0);
  static double playlistHeight(Size window, double width) =>
      (width * 1.05).clamp(220.0, 360.0).clamp(0.0, window.height * .55);
  static double bottomPadding(double safeInset, {required bool overlay}) =>
      12 + (overlay ? safeInset : 0);
}

/// Embedded lists are opaque; overlays blur only the bounded sheet behind text.
class EpisodePanelSurface extends StatelessWidget {
  const EpisodePanelSurface({
    super.key,
    required this.overlay,
    required this.child,
  });
  final bool overlay;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surface;
    final content = ColoredBox(
      color: overlay ? color.withValues(alpha: .94) : color,
      child: child,
    );
    return ClipRRect(
      borderRadius: overlay
          ? const BorderRadius.vertical(top: Radius.circular(24))
          : BorderRadius.zero,
      child: overlay && !MediaQuery.highContrastOf(context)
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: content,
            )
          : ColoredBox(color: color, child: child),
    );
  }
}
