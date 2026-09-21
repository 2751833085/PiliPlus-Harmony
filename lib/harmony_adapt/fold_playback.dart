enum HarmonyFoldPlaybackAction { none, followSystem, exitFullscreen }

/// Fold events can arrive while the platform is still entering fullscreen.
/// Keep the exit pending until that transition completes, and keep the folded
/// player inline until the user explicitly enters fullscreen or unfolds again.
class HarmonyFoldPlayback {
  bool keepInline = false;
  bool _exitPending = false;

  void reset() {
    keepInline = false;
    _exitPending = false;
  }

  HarmonyFoldPlaybackAction changed({
    required bool enabled,
    required bool windowMode,
    required bool expanded,
    required bool fullscreen,
    required bool transitioning,
  }) {
    if (!enabled || windowMode) {
      reset();
      return HarmonyFoldPlaybackAction.none;
    }
    if (expanded) {
      reset();
      return fullscreen
          ? HarmonyFoldPlaybackAction.followSystem
          : HarmonyFoldPlaybackAction.none;
    }
    _exitPending = fullscreen || transitioning;
    keepInline = _exitPending;
    return transitioning
        ? HarmonyFoldPlaybackAction.none
        : transitionFinished(fullscreen: fullscreen);
  }

  HarmonyFoldPlaybackAction transitionFinished({required bool fullscreen}) {
    final exit = _exitPending && fullscreen;
    _exitPending = false;
    return exit
        ? HarmonyFoldPlaybackAction.exitFullscreen
        : HarmonyFoldPlaybackAction.none;
  }
}
