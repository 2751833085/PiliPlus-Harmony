import 'package:flutter/material.dart';

/// Neutral surfaces for overlays above a black video, without inherited seed tints.
ThemeData shortVideoPanelTheme(ThemeData base) {
  const surface = Color(0xFF141517);
  const raised = Color(0xFF232427);
  const secondaryText = Color(0xFFB8BABF);
  return base.copyWith(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: surface,
    canvasColor: surface,
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
