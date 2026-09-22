import 'package:flutter/material.dart';

/// Establishes both typography and the surface when nested in a light app.
/// A Theme alone leaves the outer Material's DefaultTextStyle in effect.
class ShortVideoPanelSurface extends StatelessWidget {
  const ShortVideoPanelSurface({
    super.key,
    required this.base,
    required this.child,
  });

  final ThemeData base;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = shortVideoPanelTheme(base);
    return Theme(
      data: theme,
      child: Material(color: theme.colorScheme.surface, child: child),
    );
  }
}

/// Neutral surfaces for overlays above a black video, without inherited seed tints.
ThemeData shortVideoPanelTheme(ThemeData base) {
  const surface = Color(0xFF141517);
  const raised = Color(0xFF232427);
  const secondaryText = Color(0xFFB8BABF);
  return base.copyWith(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: surface,
    canvasColor: surface,
    textTheme: base.textTheme.apply(
      bodyColor: const Color(0xFFE6E7EA),
      displayColor: const Color(0xFFE6E7EA),
    ),
    colorScheme: base.colorScheme.copyWith(
      brightness: Brightness.dark,
      primary: const Color(0xFFE6E7EA),
      secondary: const Color(0xFFE6E7EA),
      primaryContainer: raised,
      secondaryContainer: raised,
      onPrimaryContainer: const Color(0xFFE6E7EA),
      onSecondaryContainer: const Color(0xFFE6E7EA),
      onInverseSurface: raised,
      surface: surface,
      surfaceContainerLowest: surface,
      surfaceContainerLow: surface,
      surfaceDim: surface,
      surfaceBright: raised,
      surfaceContainer: surface,
      surfaceContainerHigh: raised,
      surfaceContainerHighest: raised,
      onSurface: const Color(0xFFE6E7EA),
      onSurfaceVariant: secondaryText,
      surfaceTint: Colors.transparent,
    ),
    bottomSheetTheme: base.bottomSheetTheme.copyWith(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: base.dialogTheme.copyWith(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
    ),
    popupMenuTheme: base.popupMenuTheme.copyWith(
      color: raised,
      surfaceTintColor: Colors.transparent,
    ),
  );
}
