import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/plugin/pl_player/models/buffering_recovery.dart';

void main() {
  test('transient buffering does not reload; prolonged stalls are bounded', () {
    final policy = BufferingRecovery();
    bool sample(
      int seconds, {
      int position = 100,
      bool buffering = true,
      bool eligible = true,
    }) => policy.sample(
      now: Duration(seconds: seconds),
      position: position,
      buffering: buffering,
      eligible: eligible,
    );
    expect(sample(0), false);
    expect(sample(1), false);
    expect(sample(5), false);
    expect(sample(11), true);
    expect(sample(12, buffering: false), false);
    expect(sample(13), false);
    expect(sample(24), false); // retry cooldown
    expect(sample(26), true);
    expect(sample(27, buffering: false), false);
    expect(sample(28), false);
    expect(sample(80), false); // cannot loop forever
    expect(sample(81, position: 101, buffering: false), false);
    expect(sample(82, position: 101), false);
    expect(sample(93, position: 101), true); // playback really progressed
  });
  test('paused/seeking/background playback does not trigger recovery', () {
    final policy = BufferingRecovery();
    for (final t in [0, 1, 20, 60]) {
      expect(
        policy.sample(
          now: Duration(seconds: t),
          position: 100,
          buffering: true,
          eligible: false,
        ),
        false,
      );
    }
    policy.reset();
    expect(
      policy.sample(
        now: const Duration(seconds: 90),
        position: 200,
        buffering: true,
        eligible: true,
      ),
      false,
    );
  });
}
