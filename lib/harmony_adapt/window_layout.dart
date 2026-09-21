/// Window sizes are Flutter logical pixels, not the physical panel resolution.
/// Use the current app window so split screen and all fold positions work alike.
abstract final class HarmonyWindowLayout {
  static const double navigationRailMinWidth = 600;

  static bool useBottomNavigation(
    double width, {
    bool keepDock = false,
    bool sideBar = false,
  }) => keepDock || (!sideBar && width < navigationRailMinWidth);

  static bool useSettingsSplit(double width, double textScale) =>
      width >= 840 * textScale.clamp(1.0, 1.35);
}
