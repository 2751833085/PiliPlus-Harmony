import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/models_new/video/video_detail/stat.dart';

void main() {
  test(
    'missing, placeholder and invalid dislike totals are not fabricated',
    () {
      for (final value in [null, 0, -1, true, '100']) {
        final stat = VideoStat.fromJson({'dislike': value});
        expect(stat.dislikeLabel(showCount: true), '未公开');
        expect(stat.dislikeLabel(showCount: false), '点踩');
      }
    },
  );
  test('provided positive total is available only when requested', () {
    final stat = VideoStat.fromJson({'dislike': 1234});
    expect(stat.dislikeLabel(showCount: true), '1234');
    expect(stat.dislikeLabel(showCount: false), '点踩');
  });
}
