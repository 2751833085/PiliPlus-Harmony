import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

/// Horizontal seeking leaves the vertical gesture arena to the feed pager.
HorizontalDragGestureRecognizer feedSeekRecognizer({
  required VoidCallback onStart,
  required ValueChanged<double> onUpdate,
  required VoidCallback onEnd,
  required VoidCallback onCancel,
}) {
  return HorizontalDragGestureRecognizer()
    ..onStart = ((_) => onStart())
    ..onUpdate = ((event) => onUpdate(event.delta.dx))
    ..onEnd = ((_) => onEnd())
    ..onCancel = onCancel;
}
