import 'dart:math' as math;
import 'package:flutter/widgets.dart';

/// Profiles use the available window, so split windows behave like phones.
/// Orientation is independent of the number of unfolded panels.
abstract final class FeedColumns {
  static int profile(Size window) {
    final form = window.shortestSide < 600
        ? 0
        : window.longestSide < 1000
        ? 1
        : 2;
    return form * 2 + (window.width > window.height ? 1 : 0);
  }

  // The same ratio is used by the grid, cover image and transition hero.
  static double coverAspectRatio(Size window) =>
      profile(window) < 2 ? 16 / 10 : 4 / 3;

  static const labels = ['单屏竖向', '单屏横向', '双屏竖向', '双屏横向', '三屏竖向', '三屏横向'];
  static const defaults = [2, 3, 3, 3, 3, 4];

  static int resolve(Size window, double availableWidth, List<int> choices) {
    final index = profile(window);
    final requested = choices.length > index ? choices[index] : 0;
    final count = requested > 0 ? requested : defaults[index];
    // Keep cards usable in split windows and alongside navigation rails.
    return count.clamp(1, math.max(1, (availableWidth / 140).floor()));
  }
}
