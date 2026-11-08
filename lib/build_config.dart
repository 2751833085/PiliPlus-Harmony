abstract final class BuildConfig {
  // Keep the public version concise; the build number identifies each signed HAP.
  static String get releaseLabel {
    final beta = RegExp(
      r'^v?(\d+\.\d+)\.\d+-beta(?:[+-]|$)',
    ).firstMatch(versionName);
    return beta == null ? versionName : 'Beta ${beta[1]}';
  }

  static String get displayVersion => '$releaseLabel · 构建 $versionCode';
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
