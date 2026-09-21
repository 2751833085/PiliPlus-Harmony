/// Window sizes are Flutter logical pixels, not the physical panel resolution.
/// Use the current app window so split screen and all fold positions work alike.
abstract final class HarmonyWindowLayout {
  static const double navigationRailMinWidth = 600;

  static bool useBottomNavigation(double width) =>
      width < navigationRailMinWidth;
}
