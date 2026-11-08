abstract final class BuildConfig {
  // The public milestone is independent of the monotonic HAP version/build.
  static const String releaseLabel = 'Beta 1.0';
  static String get displayVersion =>
      '$releaseLabel · $versionName+$versionCode';
  static String get fullVersionTag =>
      versionTag.contains('+') ? versionTag : '$versionTag+$versionCode';
  static const int versionCode = int.fromEnvironment(
    'pili.code',
    defaultValue: 1,
  );
  static const String versionName = String.fromEnvironment(
    'pili.name',
    defaultValue: 'SNAPSHOT',
  );
  static const String versionTag = String.fromEnvironment(
    'pili.tag',
    defaultValue: versionName,
  );

  static const int buildTime = int.fromEnvironment('pili.time');
  static const String commitHash = String.fromEnvironment(
    'pili.hash',
    defaultValue: 'N/A',
  );
}
