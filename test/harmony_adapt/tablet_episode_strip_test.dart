import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/pages/video/widgets/tablet_episode_strip.dart';

void main() {
  testWidgets(
    'wide episode strip lazily scrolls, selects, and reveals the active part',
    (tester) async {
      var selected = 0;
      var expanded = 0;
      final labels = List.generate(100, (i) => '分集$i');
      Widget page(int index, {double scale = 1, List<String>? items}) =>
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 650,
                    child: TabletEpisodeStrip(
                      title: '选集',
                      labels: items ?? labels,
                      selectedIndex: index,
                      onSelected: (i) => selected = i,
                      onExpand: () => expanded++,
                    ),
                  ),
                ),
              ),
            ),
          );
      await tester.pumpWidget(page(0));
      await tester.pumpAndSettle();
      expect(find.text('100. 分集99'), findsNothing);
      await tester.tap(find.text('展开全部 · 100'));
      expect(expanded, 1);
      expect(selected, 0);
      await tester.tap(find.text('2. 分集1'));
      expect(selected, 1);
      await tester.pumpWidget(page(80, scale: 1.8));
      await tester.pumpAndSettle();
      expect(find.text('81. 分集80').hitTestable(), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(page(-1, items: []));
      await tester.pumpAndSettle();
      expect(find.byType(ListView), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
