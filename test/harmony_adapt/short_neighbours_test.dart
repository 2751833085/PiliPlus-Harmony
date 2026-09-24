import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/pages/video/shorts/session.dart';

void main() {
  final entries = List.generate(8, (i) => ShortVideoEntry(bvid: '$i'));
  List<String> window(int current, int target) => shortPreloadNeighbours(
    entries,
    current,
    target,
  ).map((e) => e.bvid).toList();
  test(
    'idle window contains next and previous without consuming live slot',
    () {
      expect(window(3, 3), ['4', '2', '5']);
      expect(window(0, 0), ['1', '2', '3']);
    },
  );
  test('rapid forward and reverse target take priority and remain bounded', () {
    expect(window(1, 5), ['5', '6', '4']);
    expect(window(6, 3), ['3', '2', '4']);
    expect(window(7, 7), ['6', '5']);
    expect(shortPreloadNeighbours([], 0, 0), isEmpty);
  });
}
