import 'dart:async';
import 'package:dio/dio.dart';

/// One speculative item. A ready API result can be consumed even if byte
/// preloading is unfinished; it never delays foreground playback to finish it.
class NextVideoPreloader<T> {
  NextVideoPreloader({required this.load, required this.warm});
  final Future<T?> Function(String bvid, int cid, CancelToken cancel) load;
  final Future<void> Function(T data, CancelToken cancel) warm;
  CancelToken? _cancel;
  (String, int, Object)? _key;
  T? _ready;
  DateTime? _until;
  bool _disposed = false;
  Future<void> prepare(String bvid, int cid, Object context) async {
    final key = (bvid, cid, context);
    final valid = _key == key && _until?.isAfter(DateTime.now()) == true;
    if (_disposed || (valid && _cancel?.isCancelled == false)) return;
    final retained = valid ? _ready : null;
    cancel();
    final token = _cancel = CancelToken();
    _key = key;
    _until = DateTime.now().add(const Duration(seconds: 45));
    final deadline = Timer(
      const Duration(seconds: 8),
      () => token.cancel('preload budget'),
    );
    try {
      final result = retained ?? await load(bvid, cid, token);
      if (_disposed || token.isCancelled || result == null || _key != key)
        return;
      _ready = result;
      await warm(result, token);
    } catch (_) {
      // Speculative failures are silent; normal playback requests can retry.
    } finally {
      deadline.cancel();
    }
  }

  T? take(String bvid, int cid, Object context) {
    final valid =
        _key == (bvid, cid, context) && _until?.isAfter(DateTime.now()) == true;
    final result = valid ? _ready : null;
    cancel();
    return result;
  }

  int? cidFor(String bvid, Object context) =>
      _key?.$1 == bvid &&
          _key?.$3 == context &&
          _until?.isAfter(DateTime.now()) == true
      ? _key?.$2
      : null;
  void suspend() => _cancel?.cancel('foreground playback needs bandwidth');
  void cancel() {
    _cancel?.cancel('preload superseded');
    _cancel = null;
    _key = null;
    _ready = null;
    _until = null;
  }

  void dispose() {
    _disposed = true;
    cancel();
  }
}
