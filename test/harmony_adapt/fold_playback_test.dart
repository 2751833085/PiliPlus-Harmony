import 'package:PiliPlus/harmony_adapt/fold_playback.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'folding fullscreen back to one panel stays inline until explicit reentry',
    () {
      final policy = HarmonyFoldPlayback();
      expect(
        policy.changed(
          enabled: true,
          windowMode: false,
          expanded: false,
          fullscreen: true,
          transitioning: false,
        ),
        HarmonyFoldPlaybackAction.exitFullscreen,
      );
      expect(policy.keepInline, isTrue);
      expect(
        policy.transitionFinished(fullscreen: false),
        HarmonyFoldPlaybackAction.none,
      );
      expect(
        policy.keepInline,
        isTrue,
        reason: 'viewport/sensor updates must not reenter fullscreen',
      );
      policy
          .reset(); // The explicit fullscreen button restores normal behavior.
      expect(policy.keepInline, isFalse);
    },
  );

  test('folding during fullscreen entry cannot lose the exit request', () {
    final policy = HarmonyFoldPlayback();
    expect(
      policy.changed(
        enabled: true,
        windowMode: false,
        expanded: false,
        fullscreen: false,
        transitioning: true,
      ),
      HarmonyFoldPlaybackAction.none,
    );
    expect(
      policy.transitionFinished(fullscreen: true),
      HarmonyFoldPlaybackAction.exitFullscreen,
    );
    expect(
      policy.transitionFinished(fullscreen: false),
      HarmonyFoldPlaybackAction.none,
    );
    expect(policy.keepInline, isTrue);
  });

  test(
    'unfolding again cancels a stale pending exit and follows the system',
    () {
      final policy = HarmonyFoldPlayback();
      policy.changed(
        enabled: true,
        windowMode: false,
        expanded: false,
        fullscreen: true,
        transitioning: true,
      );
      expect(
        policy.changed(
          enabled: true,
          windowMode: false,
          expanded: true,
          fullscreen: true,
          transitioning: true,
        ),
        HarmonyFoldPlaybackAction.followSystem,
      );
      expect(
        policy.transitionFinished(fullscreen: true),
        HarmonyFoldPlaybackAction.none,
      );
      expect(policy.keepInline, isFalse);
    },
  );

  test(
    'disabled adaptation, free windows and already inline players stay unchanged',
    () {
      for (final state in [
        (false, false, true),
        (true, true, true),
        (true, false, false),
      ]) {
        final policy = HarmonyFoldPlayback();
        expect(
          policy.changed(
            enabled: state.$1,
            windowMode: state.$2,
            expanded: false,
            fullscreen: state.$3,
            transitioning: false,
          ),
          HarmonyFoldPlaybackAction.none,
        );
        expect(policy.keepInline, isFalse);
      }
    },
  );
}
