import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/plugin/pl_player/models/video_buffer_guard.dart';

void main() {
  test('video queue wins over buffered DASH audio', () {
    final cache = VideoCacheSample.parse('''{
      "cache-duration":12,"underrun":true,
      "ts-per-stream":[{"type":"audio","cache-duration":12},
                       {"type":"video","cache-duration":0}]
    }''');
    expect(cache.seconds, 0);
    expect(cache.underrun, true);
  });
  test('invalid native data is unavailable, not an empty buffer', () {
    for (final data in [
      '',
      'unavailable',
      '[]',
      '{}',
      '{"cache-duration":-1}',
    ]) {
      expect(VideoCacheSample.parse(data).seconds, isNull);
    }
  });

  late VideoBufferGuard guard;
  setUp(() => guard = VideoBufferGuard());
  VideoBufferAction sample(
    int ms, {
    double video = 10,
    double audio = 10,
    double? seconds = 0,
    bool eligible = true,
    bool idle = false,
    double speed = 1,
  }) => guard.sample(
    now: Duration(milliseconds: ms),
    video: video,
    audio: audio,
    cache: VideoCacheSample(seconds: seconds, idle: idle),
    eligible: eligible,
    speed: speed,
  );

  test(
    'stalled video with audio advancing pauses, refills and resynchronizes',
    () {
      expect(sample(0), VideoBufferAction.none);
      expect(sample(400, audio: 10.4), VideoBufferAction.none);
      expect(sample(800, audio: 10.8), VideoBufferAction.none);
      expect(sample(1200, audio: 11.2), VideoBufferAction.hold);
      expect(guard.resumePosition, 10); // not the audio's later time
      expect(sample(1600, audio: 11.2, seconds: 0.5), VideoBufferAction.none);
      expect(sample(2000, audio: 11.2, seconds: 1), VideoBufferAction.resume);
      expect(guard.holding, true); // held until the caller completes seek/play
      guard.reset();
      expect(
        sample(2400, video: 10.4, audio: 10.4, seconds: 1),
        VideoBufferAction.none,
      );
    },
  );
  test(
    'ordinary cached playback, low-fps video and unavailable cache are not held',
    () {
      for (final seconds in [null, 2.0]) {
        guard.reset();
        sample(0, seconds: seconds);
        expect(
          sample(2400, audio: 12.4, seconds: seconds),
          VideoBufferAction.none,
        );
      }
      guard.reset();
      sample(0);
      expect(sample(800, video: 10.8, audio: 10.8), VideoBufferAction.none);
      expect(sample(1600, video: 11.6, audio: 11.6), VideoBufferAction.none);
    },
  );
  test(
    'native buffering or interrupted audio already stopped does not force pause',
    () {
      sample(0);
      expect(sample(5000), VideoBufferAction.none);
    },
  );
  test(
    'pause, seek, audio-only/background and source change invalidate a hold',
    () {
      for (var i = 0; i < 4; i++) {
        guard.reset();
        sample(0);
        sample(1200, audio: 11.2);
        expect(guard.holding, true);
        expect(
          sample(1600, eligible: false, seconds: 5),
          VideoBufferAction.none,
        );
        expect(guard.holding, false);
        expect(
          sample(2000, video: 40, audio: 40, seconds: 5),
          VideoBufferAction.none,
        );
      }
    },
  );
  test(
    'resume threshold follows speed but allows a short fully cached tail',
    () {
      sample(0);
      sample(1200, audio: 11.2);
      expect(sample(1600, seconds: 1, speed: 2), VideoBufferAction.none);
      expect(sample(2000, seconds: 2, speed: 2), VideoBufferAction.resume);
      guard.reset();
      sample(0);
      sample(1200, audio: 11.2);
      expect(sample(2000, seconds: 0.4, idle: true), VideoBufferAction.resume);
    },
  );
  test('missing or discontinuous clocks do not become a false stall', () {
    sample(0);
    expect(sample(1200, video: 2, audio: 2), VideoBufferAction.none);
    expect(
      guard.sample(
        now: const Duration(seconds: 3),
        video: null,
        audio: 3,
        cache: const VideoCacheSample(seconds: 0),
        eligible: true,
      ),
      VideoBufferAction.none,
    );
    expect(sample(4000, video: 2, audio: 4), VideoBufferAction.none);
  });
}
