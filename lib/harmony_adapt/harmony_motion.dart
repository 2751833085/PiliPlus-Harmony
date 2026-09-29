import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';

/// Shared rhythm for page entrances and tab settling, without moving the shell.
abstract final class HarmonyMotion {
  static const duration = Duration(milliseconds: 300);
  static const curve = Curves.fastOutSlowIn;
  static const tabSpring = SpringDescription(
    mass: 1,
    stiffness: 450,
    damping: 42,
  );
}
