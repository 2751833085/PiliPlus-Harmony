import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/pages/video/widgets/tablet_video_tabs.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'helpers/memory_box.dart';

void main() {
  setUpAll(() {
    GStorage.setting = MemoryBox();
    GStorage.localCache = MemoryBox();
  });
  testWidgets(
    'right pane starts with videos and swipes to comments, retaining scroll',
    (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                const Expanded(child: Center(child: Text('播放器和简介'))),
                SizedBox(
                  width: 400,
                  child: TabletVideoTabs(
                    related: ListView.builder(
                      controller: scroll,
                      itemExtent: 70,
                      itemCount: 50,
                      itemBuilder: (_, i) => Text('视频$i'),
                    ),
                    comments: const Center(child: Text('评论内容')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('视频0').hitTestable(), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -280));
      await tester.pumpAndSettle();
      final offset = scroll.offset;
      await tester.drag(find.byType(TabletVideoTabs), const Offset(-360, 0));
      await tester.pumpAndSettle();
      expect(find.text('评论内容').hitTestable(), findsOneWidget);
      expect(find.text('播放器和简介').hitTestable(), findsOneWidget);
      await tester.tap(find.text('更多视频'));
      await tester.pumpAndSettle();
      expect(scroll.offset, closeTo(offset, .01));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('disabled panels do not leave an empty selectable tab', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: TabletVideoTabs(comments: Text('评论内容'))),
    );
    expect(find.byType(TabBar), findsNothing);
    expect(find.text('评论内容'), findsOneWidget);
  });
}
