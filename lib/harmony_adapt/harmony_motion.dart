import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';

/// Shared rhythm for page entrances and tab settling, without moving the shell.
abstract final class HarmonyMotion {
  // Symmetric timing keeps entrance and exit equally legible. The native
  // shell uses the same curve; interactive back remains finger-driven.
  static const pageCurve = Cubic(.4, 0, .6, 1);
  static double pageCoverage(
    double value, {
    required bool interactive,
    bool reverse = false,
  }) => interactive
      ? value.clamp(0.0, 1.0)
      : (reverse ? pageCurve.flipped : pageCurve).transform(
          value.clamp(0.0, 1.0),
        );
  static const duration = Duration(milliseconds: 300);
  static const curve = Curves.fastOutSlowIn;
  static const tabSpring = SpringDescription(
    mass: 1,
    stiffness: 450,
    damping: 42,
  );
}
