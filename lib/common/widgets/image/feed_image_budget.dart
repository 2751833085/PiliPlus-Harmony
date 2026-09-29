import 'dart:math' as math;
import 'package:flutter/widgets.dart';

/// Restricts feed thumbnails only; detail routes keep their original density.
class FeedImageBudget extends InheritedWidget {
  const FeedImageBudget({super.key, required super.child});

  static int? cacheSize(BuildContext context, double extent) {
    if (!extent.isFinite || extent <= 0) return null;
    final density = MediaQuery.devicePixelRatioOf(context);
    final limited =
        context.dependOnInheritedWidgetOfExactType<FeedImageBudget>() != null;
    final pixels = extent * (limited ? math.min(density, 2.25) : density);
    return limited ? pixels.round().clamp(1, 1280) : pixels.round();
  }

  @override
  bool updateShouldNotify(FeedImageBudget oldWidget) => false;
}
