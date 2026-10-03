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
  testWidgets(
    'header toggles visible playlist with a brief transition and no close button',
    (
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
                header: InkWell(
                  onTap: () => fail('nested header must not consume taps'),
                  child: const Text('合集'),
                ),
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
        await tester.tapAt(tester.getCenter(find.text('合集')));
        await tester.pump();
        expect(expanded.value, i.isEven);
        expect(find.text(i.isEven ? '选集' : '推荐视频'), findsOneWidget);
        expect(find.text(i.isEven ? '推荐视频' : '选集'), findsNothing);
        expect(find.byType(AnimatedSwitcher), findsOneWidget);
        expect(find.byIcon(Icons.close), findsNothing);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpAndSettle();
      expect(find.text('推荐视频'), findsOneWidget);
    },
  );
  testWidgets(
    'late collection fades into reserved space without moving related videos',
    (tester) async {
      final expanded = ValueNotifier(false);
      addTearDown(expanded.dispose);
      for (final scale in [1.0, 1.5, 2.0]) {
        Widget page({required bool pending, required bool available}) =>
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: SizedBox(
                  width: 280,
                  child: TabletVideoSidebar(
                    expanded: expanded,
                    playlistPending: pending,
                    hasPlaylist: available,
                    header: const Text('合集标题'),
                    playlistBuilder: (_) => const Text('选集'),
                    related: const SizedBox.expand(
                      key: ValueKey('related-content'),
                    ),
                  ),
                ),
              ),
            );
        await tester.pumpWidget(page(pending: true, available: false));
        await tester.pumpAndSettle();
        final before = tester.getTopLeft(
          find.byKey(const ValueKey('related-content')),
        );
        expect(before.dy, greaterThanOrEqualTo(48));
        expect(find.text('合集标题'), findsNothing);
        await tester.pumpWidget(page(pending: false, available: true));
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('related-content'))),
          before,
        );
        final opacityFinder = find.ancestor(
          of: find.text('合集标题'),
          matching: find.byType(Opacity),
        );
        expect(tester.widget<Opacity>(opacityFinder.first).opacity, 0);
        await tester.pump(const Duration(milliseconds: 80));
        expect(
          tester.widget<Opacity>(opacityFinder.first).opacity,
          inExclusiveRange(0, 1),
        );
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('related-content'))),
          before,
        );
        await tester.pumpAndSettle();
        expect(tester.widget<Opacity>(opacityFinder.first).opacity, 1);
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('related-content'))),
          before,
        );
        await tester.pumpWidget(page(pending: false, available: false));
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('related-content'))).dy,
          0,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
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
