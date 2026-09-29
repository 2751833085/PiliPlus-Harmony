/// Bounded recovery for a network player stuck buffering without progress.
/// Sampling is driven by the player's existing timer, with no extra UI ticks.
class BufferingRecovery {
  int? _position;
  Duration? _stalledSince;
  Duration? _lastAttempt;
  int _attempts = 0;

  void reset() {
    _position = null;
    _stalledSince = null;
    _lastAttempt = null;
    _attempts = 0;
  }

  bool sample({
    required Duration now,
    required int position,
    required bool buffering,
    required bool eligible,
  }) {
    if (!eligible || !buffering || _position != position) {
      _stalledSince = null;
      // Opening a source can briefly report buffering=false without moving.
      // Do not let that transient state grant unlimited recovery attempts.
      if (eligible &&
          !buffering &&
          _position != null &&
          position > _position!) {
        _attempts = 0;
      }
      _position = position;
      return false;
    }
    _stalledSince ??= now;
    if (_attempts >= 2 ||
        now - _stalledSince! < const Duration(seconds: 10) ||
        (_lastAttempt != null &&
            now - _lastAttempt! < const Duration(seconds: 15))) {
      return false;
    }
    _attempts++;
    _lastAttempt = now;
    _stalledSince = now;
    return true;
  }
}
