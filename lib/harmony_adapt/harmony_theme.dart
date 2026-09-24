import 'package:material_ui/material_ui.dart'
    show PopupSurfaceStyle, PopupSheetStyle;
import 'package:flutter/material.dart';

/// A theme marker keeps the alternative appearance independent of persisted
/// settings, so nested themes, tests and non-Harmony builds remain predictable.
@immutable
class HarmonyStyle extends ThemeExtension<HarmonyStyle> {
  const HarmonyStyle();

  static bool enabled(BuildContext context) =>
      Theme.of(context).extension<HarmonyStyle>() != null;

  @override
  HarmonyStyle copyWith() => this;
  @override
  HarmonyStyle lerp(covariant HarmonyStyle? other, double t) => this;
}

abstract final class HarmonyTheme {
  static const backgroundLight = Color(0xFFF1F3F5);
  static const backgroundDark = Color(0xFF101113);
  static const panelDark = Color(0xFF1C1D20);
  static const cardRadius = BorderRadius.all(Radius.circular(20));

  static ColorScheme nativeColors(
    Brightness brightness, {
    ColorScheme? accentColors,
  }) {
    final dark = brightness == Brightness.dark;
    final accent =
        accentColors?.primary ??
        (dark ? const Color(0xFFFF85AC) : const Color(0xFFD93670));
    return (accentColors ??
            ColorScheme.fromSeed(
              seedColor: const Color(0xFFFB7299),
              brightness: brightness,
            ))
        .copyWith(
          primary: accent,
          secondary: accent,
          tertiary: accent,
          onPrimary:
              accentColors?.onPrimary ??
              (dark ? const Color(0xFF3D0019) : Colors.white),
          onSecondary:
              accentColors?.onPrimary ??
              (dark ? const Color(0xFF3D0019) : Colors.white),
          onTertiary:
              accentColors?.onPrimary ??
              (dark ? const Color(0xFF3D0019) : Colors.white),
          onSurface: dark ? const Color(0xFFF1F3F5) : const Color(0xFF191A1C),
          onSurfaceVariant: dark
              ? const Color(0xFFB9BBC1)
              : const Color(0xFF62656B),
          outline: dark ? const Color(0xFFA3A5AB) : const Color(0xFF74777D),
        );
  }

  static ThemeData apply(ThemeData base, {bool immersive = false}) {
    final dark = base.brightness == Brightness.dark;
    final background = dark ? backgroundDark : backgroundLight;
    final panel = dark ? panelDark : Colors.white;
    final scheme = base.colorScheme.copyWith(
      surface: panel,
      surfaceContainer: background,
      surfaceContainerLow: background,
      surfaceContainerHigh: dark
          ? const Color(0xFF292A2E)
          : const Color(0xFFE9EBEE),
      surfaceTint: Colors.transparent,
      outlineVariant: dark ? const Color(0xFF35363A) : const Color(0xFFE3E5E8),
    );
    final title = base.textTheme.titleMedium!.copyWith(
      fontSize: 16,
      height: 1.35,
    );
    final body = base.textTheme.bodyMedium!.copyWith(fontSize: 14, height: 1.4);
    final shape = RoundedRectangleBorder(borderRadius: cardRadius);
    final button = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(40, 40)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 20),
      ),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
      elevation: const WidgetStatePropertyAll(0),
      textStyle: WidgetStatePropertyAll(
        title.copyWith(fontWeight: FontWeight.w500),
      ),
      animationDuration: const Duration(milliseconds: 180),
    );
    return base.copyWith(
      extensions: [
        ...base.extensions.values.where(
          (extension) =>
              extension is! HarmonyStyle &&
              extension is! PopupSurfaceStyle &&
              extension is! PopupSheetStyle,
        ),
        const HarmonyStyle(),
        const PopupSheetStyle(),
        if (immersive) const PopupSurfaceStyle(),
      ],
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      splashFactory: NoSplash.splashFactory,
      highlightColor: scheme.primary.withValues(alpha: 0.08),
      textTheme: base.textTheme.copyWith(
        titleLarge: base.textTheme.titleLarge!.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: title,
        bodyLarge: base.textTheme.bodyLarge!.copyWith(
          fontSize: 16,
          height: 1.4,
        ),
        bodyMedium: body,
        labelMedium: base.textTheme.labelMedium!.copyWith(
          fontSize: 12,
          height: 1.4,
        ),
      ),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: title.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        titleSpacing: 8,
        toolbarHeight: 56,
      ),
      cardTheme: CardThemeData(
        color: panel,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: shape,
        clipBehavior: Clip.antiAlias,
      ),
      dialogTheme: base.dialogTheme.copyWith(
        constraints: const BoxConstraints(minWidth: 280, maxWidth: 560),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        backgroundColor: panel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titleTextStyle: title.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: body,
        clipBehavior: Clip.antiAlias,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
      bottomSheetTheme: base.bottomSheetTheme.copyWith(
        constraints: const BoxConstraints(maxWidth: 720),
        backgroundColor: panel,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
        dragHandleColor: scheme.outlineVariant,
      ),
      popupMenuTheme: base.popupMenuTheme.copyWith(
        color: immersive ? Colors.transparent : panel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: cardRadius,
          side: BorderSide(
            color: scheme.onSurface.withValues(alpha: immersive ? .1 : 0),
            width: .5,
          ),
        ),
        menuPadding: EdgeInsets.zero,
        elevation: 4,
      ),
      listTileTheme: base.listTileTheme.copyWith(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minTileHeight: 56,
        horizontalTitleGap: 16,
        titleTextStyle: title,
        subtitleTextStyle: body.copyWith(color: scheme.onSurfaceVariant),
        iconColor: scheme.onSurfaceVariant,
      ),
      filledButtonTheme: FilledButtonThemeData(style: button),
      outlinedButtonTheme: OutlinedButtonThemeData(style: button),
      textButtonTheme: TextButtonThemeData(style: button),
      elevatedButtonTheme: ElevatedButtonThemeData(style: button),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: scheme.surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary),
        ),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        trackHeight: 6,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
        trackShape: const RoundedRectSliderTrackShape(),
      ),
      checkboxTheme: base.checkboxTheme.copyWith(
        shape: const CircleBorder(),
        side: BorderSide(color: scheme.outline, width: 1.5),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: const StadiumBorder(),
        side: BorderSide.none,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 0.5,
        space: 1,
      ),
      switchTheme: base.switchTheme.copyWith(
        thumbIcon: const WidgetStatePropertyAll(null),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.outlineVariant,
        ),
        thumbColor: const WidgetStatePropertyAll(Colors.white),
      ),
    );
  }
}
