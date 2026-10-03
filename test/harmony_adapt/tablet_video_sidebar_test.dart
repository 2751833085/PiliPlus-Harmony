import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/pages/video/widgets/tablet_video_sidebar.dart';
import 'package:PiliPlus/pages/video/widgets/collapsible_playlist.dart';

void main() {
  test('tablet columns leave readable room at dual and triple fold widths', () {
    expect(TabletVideoLayout.enabled(const Size(350, 776)), isFalse);
    for (final size in [const Size(712, 776), const Size(1108, 776)]) {
      expect(TabletVideoLayout.enabled(size), isTrue);
      final side = TabletVideoLayout.sidebarWidth(size.width);
      expect(side, inInclusiveRange(260, 440));
      expect(size.width - side, greaterThanOrEqualTo(450));
    }
  });
  testWidgets('rapid playlist toggles do not duplicate keyed content', (
    tester,
  ) async {
    final expanded = ValueNotifier(false);
    addTearDown(expanded.dispose);
    final relatedKey = GlobalKey();
    final playlistKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            child: TabletVideoSidebar(
              expanded: expanded,
              header: const Text('合集'),
              hasPlaylist: true,
              related: ListView(
                key: relatedKey,
                children: const [Text('推荐视频')],
              ),
              playlistBuilder: (_) =>
                  ListView(key: playlistKey, children: const [Text('选集')]),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      expanded.value = !expanded.value;
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpAndSettle();
    expect(find.text('推荐视频'), findsOneWidget);
  });
  testWidgets('collapse retains content while height smoothly decreases', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 300,
              child: CollapsiblePlaylist(builder: (_) => const Text('选集')),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('播放列表'));
    await tester.pumpAndSettle();
    final open = tester.getSize(find.byType(CollapsiblePlaylist)).height;
    await tester.tap(find.text('播放列表'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('选集'), findsOneWidget);
    final middle = tester.getSize(find.byType(CollapsiblePlaylist)).height;
    expect(middle, lessThan(open));
    expect(middle, greaterThan(70));
    await tester.pumpAndSettle();
    expect(find.text('选集'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
