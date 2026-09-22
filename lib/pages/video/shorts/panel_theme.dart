import 'package:flutter/material.dart';

/// Neutral surfaces for overlays above a black video, retaining the app accent.
ThemeData shortVideoPanelTheme(ThemeData base) {
  const surface = Color(0xFF191A1D);
  const raised = Color(0xFF27282C);
  const secondaryText = Color(0xFFB8BABF);
  return base.copyWith(
    scaffoldBackgroundColor: surface,
    canvasColor: surface,
    colorScheme: base.colorScheme.copyWith(
      surface: surface,
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
