/// Serializes native player initialization while dropping superseded requests.
/// A ticket must also be checked after each async network boundary before its
/// result is applied, since a newer request can arrive while it is running.
class VideoRequestQueue {
  Future<void> _tail = Future.value();
  int _revision = 0;
  bool _disposed = false;
  int _pending = 0;
  bool get isBusy => _pending > 0;
  bool isCurrent(int ticket) => !_disposed && ticket == _revision;
  void invalidate() => _revision++;
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
