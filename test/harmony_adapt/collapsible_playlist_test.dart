import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/pages/video/widgets/collapsible_playlist.dart';

void main() {
  testWidgets(
    'playlist starts collapsed, expands a bounded scrollable list and can close',
    (tester) async {
      var builds = 0;
      var selected = -1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: CollapsiblePlaylist(
                    builder: (_) {
                      builds++;
                      return Column(
                        children: [
                          const Text('合集'),
                          Expanded(
                            child: ListView.builder(
                              itemCount: 30,
                              itemExtent: 50,
                              itemBuilder: (_, i) => TextButton(
                                onPressed: () => selected = i,
                                child: Text('分集 $i'),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SliverToBoxAdapter(child: Text('相关视频')),
              ],
            ),
          ),
        ),
      );
      expect(builds, 0);
      await tester.tap(find.text('播放列表'));
      await tester.pumpAndSettle();
      expect(find.text('分集 0'), findsOneWidget);
      await tester.tap(find.text('分集 0'));
      expect(selected, 0);
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('播放列表'));
      await tester.pumpAndSettle();
      expect(find.text('合集'), findsNothing);
      expect(find.text('相关视频'), findsOneWidget);
    },
  );
}
