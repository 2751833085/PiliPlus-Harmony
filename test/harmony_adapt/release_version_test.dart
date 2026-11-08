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
              'state': 'uploaded',
              'size': 1024,
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
  test('Alpha archives cannot mask the first installable Beta release', () {
    final beta = release('v3.0.0+6252')..['name'] = 'Beta 1.0';
    final alpha = release('v3.0.0+6251', asset: false)..['name'] = 'Alpha 6251';
    expect(latestHarmonyRelease([alpha, beta])?['name'], 'Beta 1.0');
    expect(
      ReleaseVersion.parse(
        '3.0.0+6251',
      )!.compareTo(ReleaseVersion.parse(beta['tag_name'])!),
      lessThan(0),
    );
  });
  test('Beta 1.0 uses its own tag and can find later Beta updates', () {
    const tag = 'v1.0.0-beta+6253';
    final beta = release(tag)..['name'] = 'Beta 1.0';
    final asset = (beta['assets'] as List).single;
    asset['browser_download_url'] =
        'https://github.com/2751833085/PiliPlus-Harmony/releases/download/v1.0.0-beta%2B6253/PiliPlus-signed.hap';
    final replaced = release('v3.0.0+6252', asset: false);
    final installed = ReleaseVersion.parse(tag)!;

    expect(installed.build, 6253);
    final current = latestHarmonyRelease([replaced, beta])!;
    expect(current, same(beta));
    expect(harmonyHapUrl(current), asset['browser_download_url']);
    expect(installed.compareTo(ReleaseVersion.parse(current['tag_name'])!), 0);

    final next = release('v1.1.0-beta+6254')..['name'] = 'Beta 1.1';
    final latest = latestHarmonyRelease([replaced, next, beta])!;
    expect(latest, same(next));
    expect(
      installed.compareTo(ReleaseVersion.parse(latest['tag_name'])!),
      lessThan(0),
    );
  });
  test('ignores unsigned, empty, pending and mismatched HAP assets', () {
    for (final change in <String, dynamic>{
      'name': 'PiliPlus-unsigned.hap',
      'size': 0,
      'state': 'starter',
      'browser_download_url':
          'https://github.com/2751833085/PiliPlus-Harmony/releases/download/v3.0.0%2B6250/PiliPlus-signed.hap',
    }.entries) {
      final data = release('v3.0.0+6252');
      (data['assets'] as List).first[change.key] = change.value;
      expect(harmonyHapUrl(data), isNull, reason: change.key);
    }
    final valid = release('v3.0.0+6252');
    final asset = (valid['assets'] as List).first;
    asset['browser_download_url'] =
        'https://github.com/2751833085/PiliPlus-Harmony/releases/download/v3.0.0%2B6252/PiliPlus-signed.hap';
    expect(harmonyHapUrl(valid), isNotNull);
    expect(
      latestHarmonyRelease([
        release('v3.0.0+9999', asset: false),
        valid,
      ])?['tag_name'],
      'v3.0.0+6252',
    );
  });
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
