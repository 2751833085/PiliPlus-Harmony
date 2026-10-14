import 'dart:convert';

/// Only the selected video's packet queue counts here. DASH audio may have
/// plenty of data while the separate video request has already stalled.
class VideoCacheSample {
  const VideoCacheSample({
    this.seconds,
    this.underrun = false,
    this.idle = false,
  });

  final double? seconds;
  final bool underrun;
  final bool idle;

  static VideoCacheSample parse(String value) {
    try {
      final map = jsonDecode(value) as Map<String, dynamic>;
      num? duration = map['cache-duration'] as num?;
      if (map['ts-per-stream'] case final List streams) {
        for (final stream in streams) {
          if (stream is Map && stream['type'] == 'video') {
            duration = stream['cache-duration'] as num?;
            break;
          }
        }
      }
      final seconds = duration?.toDouble();
      return VideoCacheSample(
        seconds: seconds != null && seconds.isFinite && seconds >= 0
            ? seconds
            : null,
        underrun: map['underrun'] == true,
        idle: map['idle'] == true,
      );
    } catch (_) {
      return const VideoCacheSample();
    }
  }
}

enum VideoBufferAction { none, hold, resume }

/// Fallback for missing mpv cache-pause events, not a frame-rate watchdog.
/// Require BOTH a depleted video queue and a stopped video clock. In the
/// pinned mpv, time-pos follows video_pts while a regular video is active.
/// Audio advancing is positive evidence that this is not an audio interruption.
class VideoBufferGuard {
  double? _video;
  double? _audioAtProgress;
  Duration? _lastProgress;
  double? resumePosition;
  bool get holding => resumePosition != null;

  void reset() {
    _video = null;
    _audioAtProgress = null;
    _lastProgress = null;
    resumePosition = null;
  }

  VideoBufferAction sample({
    required Duration now,
    required double? video,
    required double? audio,
    required VideoCacheSample cache,
    required bool eligible,
    double speed = 1,
  }) {
    if (!eligible) {
      reset();
      return VideoBufferAction.none;
    }
    if (holding) {
      final seconds = cache.seconds;
      if (seconds != null &&
          (seconds >= speed.clamp(1, 4) || (cache.idle && seconds > 0.1))) {
        return VideoBufferAction.resume;
      }
      return VideoBufferAction.none;
    }
    if (video == null ||
        audio == null ||
        !video.isFinite ||
        !audio.isFinite ||
        video < 0 ||
        audio < 0) {
      reset();
      return VideoBufferAction.none;
    }
    if (_video == null || (video - _video!).abs() > 0.05) {
      _video = video;
      _audioAtProgress = audio;
      _lastProgress = now;
      return VideoBufferAction.none;
    }
    final depleted =
        cache.underrun || (cache.seconds != null && cache.seconds! <= 0.1);
    if (depleted &&
        now - _lastProgress! >= const Duration(milliseconds: 1200) &&
        audio - _audioAtProgress! >= 0.35) {
      resumePosition = video;
      return VideoBufferAction.hold;
    }
    return VideoBufferAction.none;
  }
}

/// Explicit native cache pausing applies both when opening and reopening media.
/// Continuous refill avoids download/sleep bursts on a weak connection while
/// preserving the user's existing time and byte limits.
const harmonyNetworkBufferOptions = {
  'cache-pause': 'yes',
  'cache-pause-wait': '1',
  'cache-pause-initial': 'yes',
  'demuxer-hysteresis-secs': '0',
};
