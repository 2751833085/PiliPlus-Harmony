/// Release tags include a monotonic application build number, for example
/// v3.0.0+6216. Publication dates and commit dates are not version numbers.
class ReleaseVersion implements Comparable<ReleaseVersion> {
  const ReleaseVersion(this.major, this.minor, this.patch, this.build);
  final int major;
  final int minor;
  final int patch;
  final int build;

  static ReleaseVersion? parse(String tag) {
    final match = RegExp(
      r'^v?(\d+)\.(\d+)\.(\d+)(?:-beta)?\+(\d+)$',
    ).firstMatch(tag);
    if (match == null) return null;
    return ReleaseVersion(
      int.parse(match[1]!),
      int.parse(match[2]!),
      int.parse(match[3]!),
      int.parse(match[4]!),
    );
  }

  @override
  int compareTo(ReleaseVersion other) {
    final left = [major, minor, patch, build];
    final right = [other.major, other.minor, other.patch, other.build];
    for (var i = 0; i < left.length; i++) {
      final result = left[i].compareTo(right[i]);
      if (result != 0) return result;
    }
    return 0;
  }
}

Map<String, dynamic>? latestHarmonyRelease(dynamic response) {
  if (response is! List) return null;
  Map<String, dynamic>? latest;
  ReleaseVersion? version;
  for (final item in response) {
    if (item is! Map<String, dynamic> || item['draft'] == true) continue;
    final candidate = ReleaseVersion.parse(item['tag_name']?.toString() ?? '');
    if (candidate == null || harmonyHapUrl(item) == null) continue;
    if (version == null || candidate.compareTo(version) > 0) {
      latest = item;
      version = candidate;
    }
  }
  return latest;
}

String? harmonyHapUrl(Map data) {
  final assets = data['assets'];
  if (assets is! List) return null;
  for (final asset in assets) {
    if (asset is! Map) continue;
    final name = asset['name']?.toString() ?? '';
    final url = Uri.tryParse(asset['browser_download_url']?.toString() ?? '');
    if (name.endsWith('.hap') &&
        url?.scheme == 'https' &&
        url?.host == 'github.com' &&
        url!.path.startsWith(
          '/2751833085/PiliPlus-Harmony/releases/download/',
        )) {
      return url.toString();
    }
  }
  return null;
}
