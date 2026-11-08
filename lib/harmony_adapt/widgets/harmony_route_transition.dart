import 'package:PiliPlus/harmony_adapt/harmony_motion.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Updates the existing fractional translation directly in the paint phase.
/// ModalRoute already rebuilds its transition on each tick; another animated
/// widget here would duplicate subscriptions/builds on every page entrance.
/// The page stays live, with its original hit testing and semantics transform.
/// Only the arriving or departing page moves. A page under another route
/// stays fixed while the new page covers or reveals it.
class HarmonyRouteTransition extends SingleChildRenderObjectWidget {
  const HarmonyRouteTransition({
    super.key,
    required this.animation,
    this.userGestureInProgress,
    required super.child,
  });

  final Animation<double> animation;
  final ValueListenable<bool>? userGestureInProgress;

  @override
  RenderFractionalTranslation createRenderObject(BuildContext context) =>
      _RenderHarmonyRouteTransition(
        animation,
        userGestureInProgress,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderFractionalTranslation renderObject,
  ) => (renderObject as _RenderHarmonyRouteTransition).updateAnimations(
    animation,
    userGestureInProgress,
  );
}

class _RenderHarmonyRouteTransition extends RenderFractionalTranslation {
  _RenderHarmonyRouteTransition(
    this._animation,
    this._userGestureInProgress,
  ) : super(translation: Offset.zero) {
    _updateTranslation();
  }

  Animation<double> _animation;
  ValueListenable<bool>? _userGestureInProgress;

  void updateAnimations(
    Animation<double> animation,
    ValueListenable<bool>? userGestureInProgress,
  ) {
    if (identical(animation, _animation) &&
        identical(userGestureInProgress, _userGestureInProgress)) {
      return;
    }
    if (attached) _removeListeners();
    _animation = animation;
    _userGestureInProgress = userGestureInProgress;
    if (attached) _addListeners();
    _updateTranslation();
  }

  void _addListeners() {
    _animation.addListener(_updateTranslation);
    _userGestureInProgress?.addListener(_updateTranslation);
  }

  void _removeListeners() {
    _animation.removeListener(_updateTranslation);
    _userGestureInProgress?.removeListener(_updateTranslation);
  }

  void _updateTranslation() {
    final interactive = _userGestureInProgress?.value == true;
    final primary = HarmonyMotion.pageCoverage(
      _animation.value,
      interactive: interactive,
      reverse: _animation.status == AnimationStatus.reverse,
    );
    // RenderFractionalTranslation invalidates paint/semantics, never layout.
    translation = Offset(1 - primary, 0);
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
