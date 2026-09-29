import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/common/widgets/scroll_physics.dart';
import 'package:PiliPlus/harmony_adapt/harmony_motion.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'helpers/memory_box.dart';

void main() {
  setUpAll(() => GStorage.setting = MemoryBox());
  for (final width in [350.0, 1108.0]) {
    testWidgets('tabs allow taps, horizontal drag and nested vertical scrolling at $width', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 800);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: DefaultTabController(
        length: 3, animationDuration: HarmonyMotion.duration,
        child: Scaffold(body: Column(children: [
          const TabBar(tabs: [Tab(text: '推荐'), Tab(text: '热门'), Tab(text: '分区')]),
          Expanded(child: tabBarView(children: [
            for (var page = 0; page < 3; page++)
              ListView.builder(key: PageStorageKey(page), itemCount: 60, itemExtent: 60,
                itemBuilder: (_, item) => Text('page $page row $item')),
          ])),
        ])),
      )));
      await tester.tap(find.text('热门'));
      await tester.pumpAndSettle();
      expect(find.text('page 1 row 0').hitTestable(), findsOneWidget);
      await tester.drag(find.text('page 1 row 0'), Offset(-width * .8, 0));
      await tester.pumpAndSettle();
      expect(find.text('page 2 row 0').hitTestable(), findsOneWidget);
      await tester.drag(find.text('page 2 row 5'), const Offset(0, -350));
      await tester.pumpAndSettle();
      expect(find.text('page 2 row 0').hitTestable(), findsNothing);
      await tester.tap(find.text('推荐'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('热门'));
      await tester.pumpAndSettle();
      expect(find.text('page 1 row 0').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
