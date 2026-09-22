/// Playback context supplied by a page without coupling the player to its UI.
abstract interface class PortraitPlaybackOwner {
  bool get shortVideoMode;
}

/// A page can recover a failed media route without retrying the same URL.
abstract interface class NetworkPlaybackOwner {
  bool get usesOverseasRoutes;
  bool get usesPreloadedMedia;
  void retryNetworkRoute();
}
