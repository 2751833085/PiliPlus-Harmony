/// Wait briefly for the active source's buffer signal before seeking. The
/// stream timeout closes the subscription even when the source is silent.
Future<bool> waitForSeekBuffer(
  Stream<Duration> buffer,
  bool Function() isCurrent,
) async {
  await for (final _ in buffer.timeout(
    const Duration(milliseconds: 250),
    onTimeout: (sink) => sink.close(),
  )) {
    break;
  }
  return isCurrent();
}
