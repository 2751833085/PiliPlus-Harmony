import 'dart:async';
import 'package:dio/dio.dart';

class _Prepared<T> {
  _Prepared(this.retained);
  final T? retained;
  final cancel = CancelToken();
  final ready = Completer<T?>();
  final until = DateTime.now().add(const Duration(seconds: 45));
  T? data;
  Future<void>? task;
}

/// A bounded moving window. Foreground playback joins an in-flight API request
/// and keeps its byte transfer alive instead of cancelling and downloading twice.
class NextVideoPreloader<T> {
  NextVideoPreloader({
    required this.load,
    required this.warm,
    this.capacity = 4,
  });
  final Future<T?> Function(String bvid, int cid, CancelToken cancel) load;
  final Future<void> Function(T data, CancelToken cancel) warm;
  final int capacity;
  final _items = <(String, int, Object), _Prepared<T>>{};
  bool _disposed = false;
  Iterable<T> get values => _items.values.map((e) => e.data).whereType<T>();

  Future<void> prepare(String bvid, int cid, Object context) {
    if (_disposed) return Future.value();
    final key = (bvid, cid, context);
    final old = _items[key];
    final valid = old?.until.isAfter(DateTime.now()) == true;
    if (valid && !old!.cancel.isCancelled) return old.task ?? Future.value();
    _remove(key);
    while (_items.length >= capacity) {
      _remove(_items.keys.first);
    }
    final item = _Prepared<T>(valid ? old?.data : null);
    _items[key] = item;
    return item.task = _run(key, item);
  }

  Future<void> _run((String, int, Object) key, _Prepared<T> item) async {
    final deadline = Timer(const Duration(seconds: 8), () {
      item.cancel.cancel('preload budget');
      if (!item.ready.isCompleted) item.ready.complete(null);
    });
    try {
      final result = item.retained ?? await load(key.$1, key.$2, item.cancel);
      if (_disposed ||
          item.cancel.isCancelled ||
          result == null ||
          !identical(_items[key], item))
        return;
      item.data = result;
      item.ready.complete(result);
      await warm(result, item.cancel);
    } catch (_) {
      // Foreground requests retain their ordinary error handling and retry.
    } finally {
      deadline.cancel();
      if (!item.ready.isCompleted) item.ready.complete(null);
      if (item.data == null && identical(_items[key], item)) _remove(key);
    }
  }

  Future<T?> take(String bvid, int cid, Object context) async {
    final item = _items[(bvid, cid, context)];
    if (item == null || !item.until.isAfter(DateTime.now())) return null;
    final result = item.data ?? await item.ready.future;
    return _disposed || !identical(_items[(bvid, cid, context)], item)
        ? null
        : result;
  }

  int? cidFor(String bvid, Object context) => _items.keys
      .where(
        (key) =>
            key.$1 == bvid &&
            key.$3 == context &&
            _items[key]!.until.isAfter(DateTime.now()),
      )
      .firstOrNull
      ?.$2;

  void retain(Set<String> bvids, Object context) {
    for (final key in _items.keys.toList()) {
      if (key.$3 != context ||
          !bvids.contains(key.$1) ||
          !_items[key]!.until.isAfter(DateTime.now()))
        _remove(key);
    }
  }

  void _remove((String, int, Object) key) {
    final item = _items.remove(key);
    if (item == null) return;
    item.cancel.cancel('outside preload window');
    if (!item.ready.isCompleted) item.ready.complete(null);
  }

  void suspend() {
    for (final item in _items.values) {
      item.cancel.cancel('background');
      if (!item.ready.isCompleted) item.ready.complete(null);
    }
  }

  void cancel() {
    for (final key in _items.keys.toList()) {
      _remove(key);
    }
  }

  void dispose() {
    _disposed = true;
    cancel();
  }
}
