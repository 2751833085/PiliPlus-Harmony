import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/models/video/play/url.dart';
import 'package:PiliPlus/models/common/video/video_quality.dart';

void main() {
  PlayUrlModel model(List<int> streams) => PlayUrlModel(
    acceptQuality: [112, 80, 64, 32, 16],
    dash: Dash(
      video: [
        for (final id in streams)
          VideoItem(id: id, quality: VideoQuality.fromCode(id)),
      ],
    ),
  );
  test('missing advertised quality always resolves to a returned stream', () {
    final data = model([80, 32, 16]);
    expect(data.canDeferQualitySupplement(64), isFalse);
    // The supplemental request may still not supply 64 (e.g. translation).
    expect(data.findAvailableVideoQuality(64), 32);
    expect(
      data.dash!.video!.where(
        (v) => v.id == data.findAvailableVideoQuality(64),
      ),
      isNotEmpty,
    );
  });
  test(
    'AI-capable restricted response and unordered streams remain playable',
    () {
      for (final streams in [
        [32, 16],
        [16, 32],
      ]) {
        final data = model(streams);
        expect(data.findAvailableVideoQuality(127), 32);
        expect(data.canDeferQualitySupplement(127), isTrue);
        expect(data.findAvailableVideoQuality(6), 16);
      }
    },
  );
  test('language metadata does not change selection of actual streams', () {
    final data = PlayUrlModel.fromJson({
      'quality': 64,
      'accept_quality': [112, 80, 64, 32, 16],
      'cur_language': 'en',
      'language': {
        'support': true,
        'items': [
          {'lang': 'en', 'title': 'English', 'production_type': 2},
        ],
      },
      'dash': {
        'video': [
          {'id': 32, 'baseUrl': 'https://example.test/video', 'codecs': 'avc1'},
        ],
        'audio': null,
      },
    });
    expect(data.language!.items!.single.isAi, isTrue);
    expect(data.curLanguage, 'en');
    expect(data.findAvailableVideoQuality(64), 32);
    expect(data.dash!.audio, isNull);
  });
}
