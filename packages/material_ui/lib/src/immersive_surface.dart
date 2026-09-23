import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'popup_surface.dart' show PopupSurfaceStyle;

/// One clipped backdrop per surface. High contrast and reduced motion
/// use an opaque fill; content and hit targets are unchanged.
class ImmersiveSurface extends StatelessWidget {
  const ImmersiveSurface({
    super.key,
    required this.child,
    this.color,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
  });
  final Widget child;
  final Color? color;
  final BorderRadius borderRadius;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = color ?? theme.colorScheme.surface;
    final immersive =
        theme.extension<PopupSurfaceStyle>() != null &&
        !MediaQuery.highContrastOf(context) &&
        !MediaQuery.disableAnimationsOf(context);
    final content = Material(type: MaterialType.transparency, child: child);
    return ClipRRect(
      borderRadius: borderRadius,
      child: immersive
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  border: Border.all(
                    color: Colors.white.withValues(
                      alpha: theme.brightness == Brightness.dark ? .12 : .75,
                    ),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      (theme.brightness == Brightness.dark
                              ? const Color(0xFF25262A)
                              : const Color(0xFFF7F8FA))
                          .withValues(alpha: .82),
                      (theme.brightness == Brightness.dark
                              ? const Color(0xFF25262A)
                              : const Color(0xFFF7F8FA))
                          .withValues(alpha: .72),
                    ],
                  ),
                ),
                child: content,
              ),
            )
          : ColoredBox(color: base, child: content),
    );
  }
}
