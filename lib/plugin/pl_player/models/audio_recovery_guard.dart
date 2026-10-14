/// Detect a previously advancing audio clock that stops after network buffering.
/// This cannot detect physically silent output with a healthy audio clock.
class AudioRecoveryGuard {
  double? _audio;
  double? _video;
  bool _heardProgress = false;
  Duration? _bufferedAt;
  Duration? _stalledAt;
  Duration? _attemptAt;
  int _attempts = 0;

  void reset() {
    _audio = _video = null;
    _heardProgress = false;
    _bufferedAt = _stalledAt = _attemptAt = null;
    _attempts = 0;
  }

  bool sample({
    required Duration now,
    required double? video,
    required double? audio,
    required bool buffering,
    required bool eligible,
  }) {
    if (!eligible || video == null || !video.isFinite) {
      _stalledAt = null;
      return false;
    }
    if (buffering) {
      _bufferedAt = now;
      _stalledAt = null;
      return false;
    }
    final validAudio = audio != null && audio.isFinite && audio >= 0;
    final audioProgress = validAudio && _audio != null && audio > _audio! + .05;
    if (audioProgress) _heardProgress = true;
    final videoProgress = _video != null && video > _video! + .05;
    _video = video;
    if (validAudio) _audio = audio;
    if (!_heardProgress ||
        _bufferedAt == null ||
        now - _bufferedAt! > const Duration(seconds: 30) ||
        !videoProgress ||
        audioProgress) {
      _stalledAt = null;
      return false;
    }
    _stalledAt ??= now;
    if (now - _stalledAt! < const Duration(seconds: 3) ||
        _attempts >= 2 ||
        (_attemptAt != null &&
            now - _attemptAt! < const Duration(seconds: 15))) {
      return false;
    }
    _attempts++;
    _attemptAt = now;
    _stalledAt = null;
    return true;
  }
}
