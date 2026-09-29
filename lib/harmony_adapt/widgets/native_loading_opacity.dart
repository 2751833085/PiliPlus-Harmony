import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Sends the latest alpha directly to ArkUI, with at most one update in flight.
/// Intermediate drag frames are coalesced; the final zero is never discarded.
class NativeLoadingOpacity {
  MethodChannel? _channel;
  double _target = 1;
  double? _sent;
  bool _sending = false;

  void attach(int viewId) {
    _channel = MethodChannel('piliplus/native-loading/$viewId');
    _sent = null;
    _send();
  }

  void update(double opacity) {
    _target = opacity.clamp(0.0, 1.0);
    _send();
  }

  void dispose() => _channel = null;

  void _send() {
    final channel = _channel;
    if (channel == null || _sending || _sent == _target) return;
    final value = _target;
    _sending = true;
    var succeeded = false;
    channel
        .invokeMethod<void>('setOpacity', value)
        .then<void>(
          (_) {
            succeeded = true;
            if (identical(channel, _channel)) _sent = value;
          },
          onError: (Object error, StackTrace stack) {
            // A disposed platform view can race its last animation frame.
            debugPrint('Native loading opacity update failed: $error');
          },
        )
        .whenComplete(() {
          _sending = false;
          if (succeeded || !identical(channel, _channel)) _send();
        });
  }
}
