import 'package:PiliPlus/harmony_adapt/harmony_motion.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Updates the existing fractional translation directly in the paint phase.
/// ModalRoute already rebuilds its transition on each tick; another animated
/// widget here would duplicate subscriptions/builds on every page entrance.
/// The page stays live, with its original hit testing and semantics transform.
class HarmonyRouteTransition extends SingleChildRenderObjectWidget {
  const HarmonyRouteTransition({
    super.key,
    required this.animation,
    required this.secondaryAnimation,
    this.userGestureInProgress,
    required super.child,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final ValueListenable<bool>? userGestureInProgress;

  @override
  RenderFractionalTranslation createRenderObject(BuildContext context) =>
      _RenderHarmonyRouteTransition(
        animation,
        secondaryAnimation,
        userGestureInProgress,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderFractionalTranslation renderObject,
  ) => (renderObject as _RenderHarmonyRouteTransition).updateAnimations(
    animation,
    secondaryAnimation,
    userGestureInProgress,
  );
}

class _RenderHarmonyRouteTransition extends RenderFractionalTranslation {
  _RenderHarmonyRouteTransition(
    this._animation,
    this._secondaryAnimation,
    this._userGestureInProgress,
  ) : super(translation: Offset.zero) {
    _updateTranslation();
  }

  Animation<double> _animation;
  Animation<double> _secondaryAnimation;
  ValueListenable<bool>? _userGestureInProgress;

  void updateAnimations(
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    ValueListenable<bool>? userGestureInProgress,
  ) {
    if (identical(animation, _animation) &&
        identical(secondaryAnimation, _secondaryAnimation) &&
        identical(userGestureInProgress, _userGestureInProgress)) {
      return;
    }
    if (attached) _removeListeners();
    _animation = animation;
    _secondaryAnimation = secondaryAnimation;
    _userGestureInProgress = userGestureInProgress;
    if (attached) _addListeners();
    _updateTranslation();
  }

  void _addListeners() {
    _animation.addListener(_updateTranslation);
    _secondaryAnimation.addListener(_updateTranslation);
    _userGestureInProgress?.addListener(_updateTranslation);
  }

  void _removeListeners() {
    _animation.removeListener(_updateTranslation);
    _secondaryAnimation.removeListener(_updateTranslation);
    _userGestureInProgress?.removeListener(_updateTranslation);
  }

  void _updateTranslation() {
    final interactive = _userGestureInProgress?.value == true;
    final primary = HarmonyMotion.pageCoverage(
      _animation.value,
      interactive: interactive,
      reverse: _animation.status == AnimationStatus.reverse,
    );
    final secondary = HarmonyMotion.pageCoverage(
      _secondaryAnimation.value,
      interactive: interactive,
      reverse: _secondaryAnimation.status == AnimationStatus.reverse,
    );
    // RenderFractionalTranslation invalidates paint/semantics, never layout.
    translation = Offset(1 - primary - .2 * secondary, 0);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _addListeners();
    _updateTranslation();
  }

  @override
  void detach() {
    _removeListeners();
    super.detach();
  }
}
