import 'dart:ui' show ImageFilter, TileMode;
import 'package:material_ui/material_ui.dart';

/// The fixed bottom bar samples only its own bounds. Keep destination feedback
/// outside the backdrop layer so presses do not repaint the material subtree.
class HarmonyNavigationSurface extends StatelessWidget {
  const HarmonyNavigationSurface({
    super.key,
    required this.translucent,
    required this.child,
  });

  final bool translucent;
  final Widget child;
  static final _thinBlur = ImageFilter.blur(
    sigmaX: 6,
    sigmaY: 6,
    tileMode: TileMode.clamp,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final frosted =
        translucent &&
        theme.extension<PopupSurfaceStyle>() != null &&
        !MediaQuery.highContrastOf(context) &&
        !MediaQuery.disableAnimationsOf(context);
    final neutral = dark ? Colors.black : Colors.white;
    final background = frosted
        ? BackdropFilter(
            filter: _thinBlur,
            child: DecoratedBox(
              decoration: BoxDecoration(
                // Match the top bar's neutral mask, with enough coverage to
                // keep icons legible over the moving feed.
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    neutral.withValues(alpha: .75),
                    neutral.withValues(alpha: .55),
                  ],
                ),
              ),
            ),
          )
        : ColoredBox(
            color: dark ? const Color(0xFF25262A) : const Color(0xFFF7F8FA),
          );
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: ClipRect(child: RepaintBoundary(child: background)),
          ),
        ),
        RepaintBoundary(
          child: Material(type: MaterialType.transparency, child: child),
        ),
      ],
    );
  }
}
