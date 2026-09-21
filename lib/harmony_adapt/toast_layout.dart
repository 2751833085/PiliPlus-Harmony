import 'dart:math' as math;

abstract final class HarmonyToastLayout {
  static double bottom({
    required double safeBottom,
    required double keyboardBottom,
    required double dockBottom,
    double scale = 1,
  }) => math.max(
    math.max(safeBottom + 24, keyboardBottom + 24),
    dockBottom > 0 ? dockBottom / scale + 16 : 0,
  );
}
