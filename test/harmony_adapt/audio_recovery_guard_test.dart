import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/plugin/pl_player/models/audio_recovery_guard.dart';

void main() {
  test('buffered video advances while known audio stops: bounded recovery', () {
    final guard = AudioRecoveryGuard();
    bool sample(int t, double? audio, {bool buffering = false}) => guard.sample(
      now: Duration(seconds: t),
      video: t.toDouble(),
      audio: audio,
      buffering: buffering,
      eligible: true,
    );
    expect(sample(0, 0), false);
    expect(sample(1, 1), false);
    expect(sample(2, 1, buffering: true), false);
    expect(sample(3, 1), false);
    expect(sample(5, 1), false);
    expect(sample(6, 1), true);
    for (var t = 7; t < 21; t++) expect(sample(t, null), false);
    expect(sample(21, null), true);
    for (var t = 22; t < 60; t++) expect(sample(t, null), false);
  });
  test('silent clips and healthy audio never trigger output recovery', () {
    for (final silent in [true, false]) {
      final guard = AudioRecoveryGuard();
      for (var t = 0; t < 40; t++) {
        expect(
          guard.sample(
            now: Duration(seconds: t),
            video: t.toDouble(),
            audio: silent ? null : t.toDouble(),
            buffering: t == 5,
            eligible: true,
          ),
          false,
        );
      }
    }
  });
  test(
    'user mute and paused playback are ineligible, reset forgets old source',
    () {
      final guard = AudioRecoveryGuard();
      for (var t = 0; t < 20; t++) {
        expect(
          guard.sample(
            now: Duration(seconds: t),
            video: t.toDouble(),
            audio: 0,
            buffering: t == 1,
            eligible: false,
          ),
          false,
        );
      }
      guard.reset();
      expect(
        guard.sample(
          now: const Duration(seconds: 25),
          video: 25,
          audio: null,
          buffering: false,
          eligible: true,
        ),
        false,
      );
    },
  );
}
