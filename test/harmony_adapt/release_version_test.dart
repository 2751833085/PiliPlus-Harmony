import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/utils/release_version.dart';

void main() {
  test('version comparison uses version and build, not release dates', () {
    final current = ReleaseVersion.parse('v3.0.0+6216')!;
    expect(current.compareTo(ReleaseVersion.parse('3.0.0+6216')!), 0);
    expect(
      current.compareTo(ReleaseVersion.parse('v3.0.0+6215')!),
      greaterThan(0),
    );
    expect(
      current.compareTo(ReleaseVersion.parse('v3.0.0+6217')!),
      lessThan(0),
    );
    expect(current.compareTo(ReleaseVersion.parse('v3.1.0+1')!), lessThan(0));
    expect(ReleaseVersion.parse('SNAPSHOT'), isNull);
  });
  Map<String, dynamic> release(
    String tag, {
    bool draft = false,
    bool asset = true,
  }) => {
    'tag_name': tag,
    'draft': draft,
    'prerelease': true,
    'assets': asset
        ? [
            {
              'name': 'PiliPlus-signed.hap',
              'browser_download_url':
                  'https://github.com/2751833085/PiliPlus-Harmony/releases/download/$tag/PiliPlus-signed.hap',
            },
          ]
        : [],
  };
  test(
    'selects highest published installable beta and ignores drafts/missing HAP',
    () {
      expect(
        latestHarmonyRelease([
          release('v3.0.0+6215'),
          release('v3.0.0+6218', draft: true),
          release('v3.0.0+6216'),
          release('v3.0.0+6219', asset: false),
        ])?['tag_name'],
        'v3.0.0+6216',
      );
      expect(latestHarmonyRelease({'message': 'rate limited'}), isNull);
      expect(latestHarmonyRelease([]), isNull);
    },
  );
  test('rejects unrelated download links', () {
    expect(
      harmonyHapUrl({
        'assets': [
          {
            'name': 'a.hap',
            'browser_download_url': 'https://example.com/a.hap',
          },
        ],
      }),
      isNull,
    );
  });
}
