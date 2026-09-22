import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:PiliPlus/models/common/enum_with_label.dart';

enum ShortSwipeAction with EnumWithLabel {
  seek('调整进度'),
  comments('打开评论区'),
  author('打开作者视频页');

  const ShortSwipeAction(this.label);
  @override
  final String label;
}

/// Separate tap/double-tap recognizers share the arena: a double tap must never
/// first toggle the chrome. Horizontal actions are fixed for one gesture.
class ShortVideoGestures {
  ShortVideoGestures({
    required this.onTap,
    required this.onDoubleTap,
    required this.leftAction,
    required this.rightAction,
    required this.onSeekStart,
    required this.onSeekUpdate,
    required this.onSeekEnd,
    required this.onSeekCancel,
    required this.onNavigate,
  }) {
    tap = TapGestureRecognizer()..onTap = onTap;
    doubleTap = DoubleTapGestureRecognizer()..onDoubleTap = onDoubleTap;
    horizontal = HorizontalDragGestureRecognizer()
      ..onStart = ((_) {
        _dx = 0;
        _action = null;
        _direction = 0;
      })
      ..onUpdate = ((event) {
        _dx += event.delta.dx;
        if (_action == null) {
          _direction = _dx.sign;
          _action = _dx < 0 ? leftAction() : rightAction();
          if (_action == ShortSwipeAction.seek) onSeekStart();
        }
        if (_action == ShortSwipeAction.seek) onSeekUpdate(event.delta.dx);
      })
      ..onEnd = ((_) {
        if (_action == ShortSwipeAction.seek) {
          onSeekEnd();
        } else if (_action != null &&
            _dx.abs() >= 64 &&
            _dx.sign == _direction) {
          onNavigate(_action!);
        }
        _action = null;
      })
      ..onCancel = (() {
        if (_action == ShortSwipeAction.seek) onSeekCancel();
        _action = null;
      });
  }
  final VoidCallback onTap, onDoubleTap, onSeekStart, onSeekEnd, onSeekCancel;
  final ValueChanged<double> onSeekUpdate;
  final ValueGetter<ShortSwipeAction> leftAction, rightAction;
  final ValueChanged<ShortSwipeAction> onNavigate;
  late final TapGestureRecognizer tap;
  late final DoubleTapGestureRecognizer doubleTap;
  late final HorizontalDragGestureRecognizer horizontal;
  double _dx = 0, _direction = 0;
  ShortSwipeAction? _action;
  void addPointer(PointerDownEvent event) {
    tap.addPointer(event);
    doubleTap.addPointer(event);
    horizontal.addPointer(event);
  }

  void dispose() {
    tap.dispose();
    doubleTap.dispose();
    horizontal.dispose();
  }
}
