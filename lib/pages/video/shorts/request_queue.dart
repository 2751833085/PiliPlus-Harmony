/// Serializes native player initialization while dropping superseded requests.
/// A ticket must also be checked after each async network boundary before its
/// result is applied, since a newer request can arrive while it is running.
class VideoRequestQueue {
  Future<void> _tail = Future.value();
  int _revision = 0;
  bool _disposed = false;
  int _pending = 0;
  final Map<Object, (int, Future<void>)> _inFlight = {};

  /// Repeated play taps join the same open, rather than superseding and reopening.
  Future<void> runLatest(Object key, Future<void> Function(int) task) {
    final cached = _inFlight[key];
    if (cached != null && isCurrent(cached.$1)) return cached.$2;
    final work = run(task);
    late Future<void> joined;
    joined = work.whenComplete(() {
      if (identical(_inFlight[key]?.$2, joined)) _inFlight.remove(key);
    });
    _inFlight[key] = (_revision, joined);
    return joined;
  }

  bool get isBusy => _pending > 0;
  bool isCurrent(int ticket) => !_disposed && ticket == _revision;
  void invalidate() {
    _revision++;
    _inFlight.clear();
  }

  void dispose() {
    _disposed = true;
    invalidate();
  }

  Future<void> run(Future<void> Function(int ticket) task) {
    final ticket = ++_revision;
    _pending++;
    final work = _tail.then((_) async {
      try {
        if (isCurrent(ticket)) await task(ticket);
      } finally {
        _pending--;
      }
    });
    // A failed request must not poison the queue for subsequent retries.
    _tail = work.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return work;
  }
}
