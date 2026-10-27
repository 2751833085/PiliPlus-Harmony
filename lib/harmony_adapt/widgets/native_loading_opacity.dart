import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Coalesces alpha independently for each platform-view generation. A retired
/// view's callbacks can neither delay nor take ownership of its replacement.
class NativeLoadingOpacity {
  MethodChannel? _channel;
  double _target = 1;
  double? _sent;
  bool _sending = false;
  bool _disposed = false;
  int _generation = 0;

  /// Reserve a fresh view generation before removing/changing the OhosView key.
  /// Retaining the latest target lets a replacement attach without a stale alpha.
  int detach() {
    _generation++;
    _channel = null;
    _sent = null;
    _sending = false;
    return _generation;
  }

  bool canAttach(int generation) =>
      !_disposed && generation == _generation && _channel == null;

  bool attach(int viewId, {int? generation}) {
    if (_disposed) return false;
    final targetGeneration = generation ?? detach();
    if (!canAttach(targetGeneration)) return false;
    _channel = MethodChannel('piliplus/native-loading/$viewId');
    _send();
    return true;
  }

  void update(double opacity) {
    if (_disposed) return;
    _target = opacity.clamp(0.0, 1.0);
    _send();
  }

  void dispose() {
    detach();
    _disposed = true;
  }

  void _send() {
    final channel = _channel;
    if (_disposed || channel == null || _sending || _sent == _target) return;
    final generation = _generation;
    bool current() =>
        !_disposed && generation == _generation && identical(channel, _channel);
    final value = _target;
    _sending = true;
    var succeeded = false;
    channel
        .invokeMethod<void>('setOpacity', value)
        .then<void>(
          (_) {
            if (!current()) return;
            succeeded = true;
            _sent = value;
          },
          onError: (Object error, StackTrace stack) {
            // Only explicitly retired views are ignored. An active view's real
            // failure remains visible rather than being silently swallowed.
            if (current())
              debugPrint('Native loading opacity update failed: $error');
          },
        )
        .whenComplete(() {
          if (!current()) return;
          _sending = false;
          if (succeeded || _target != value) _send();
        });
  }
}
