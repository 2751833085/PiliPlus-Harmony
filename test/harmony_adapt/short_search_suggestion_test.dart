import 'package:PiliPlus/models_new/video/video_tag/data.dart';
import 'package:PiliPlus/pages/video/shorts/search_suggestion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prefer a specific video tag occurring in the title', () {
    expect(
      shortVideoSearchTerm(
        title: '雪山铁路的旅途',
        tags: [
          VideoTagItem(tagName: '旅行'),
          VideoTagItem(tagName: '铁路'),
          VideoTagItem(tagName: '雪山铁路'),
        ],
      ),
      '雪山铁路',
    );
  });
  test('use existing topic metadata and ignore BGM discovery labels', () {
    expect(
      shortVideoSearchTerm(
        title: '出发了',
        tags: [
          VideoTagItem(tagName: '发现背景音乐', tagType: 'bgm'),
          VideoTagItem(tagName: '  铁路旅行  ', tagType: 'topic'),
          VideoTagItem(tagName: '铁路旅行'),
        ],
      ),
      '铁路旅行',
    );
  });
  test('use full title when tags are missing and omit empty metadata', () {
    expect(shortVideoSearchTerm(title: '  测试 & 海边?  '), '测试 & 海边?');
    expect(shortVideoSearchTerm(tags: [VideoTagItem(tagName: ' ')]), isNull);
    expect(shortVideoSearchTerm(title: ' '), isNull);
  });
}
