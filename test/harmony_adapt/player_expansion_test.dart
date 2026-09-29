import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/pages/video/widgets/player_expansion.dart';

void main() {
  testWidgets(
    'expanded layouts fit every intermediate frame and retain panels',
    (tester) async {
      final panelKey = GlobalKey();
      for (final size in [
        const Size(390, 844),
        const Size(760, 850),
        const Size(1200, 840),
      ]) {
        await tester.binding.setSurfaceSize(size);
        for (final axis in Axis.values) {
          Element? element;
          for (final p in [0.0, .1, .35, .75, 1.0, .8, .4, 0.0]) {
            final inline = axis == Axis.horizontal
                ? size.width * .6
                : size.height * .35;
            final full = axis == Axis.horizontal ? size.width : size.height;
            final extent = expandedPlayerExtent(inline, full, p);
            final panel = PlayerExpansionPanel(
              progress: p,
              axis: axis,
              child: SizedBox(
                key: panelKey,
                width: axis == Axis.horizontal ? full - inline : size.width,
                height: axis == Axis.vertical ? full - inline : size.height,
                child: const Text('保留评论滚动位置和输入状态'),
              ),
            );
            final player = SizedBox(
              key: const ValueKey('player'),
              width: axis == Axis.horizontal ? extent : size.width,
              height: axis == Axis.vertical ? extent : size.height,
            );
            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: Flex(
                    direction: axis,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [player, panel],
                  ),
                ),
              ),
            );
            expect(tester.takeException(), isNull, reason: '$size $axis $p');
            element ??= panelKey.currentContext as Element;
            expect(identical(element, panelKey.currentContext), isTrue);
            final rect = tester.getRect(find.byKey(const ValueKey('player')));
            expect(
              axis == Axis.horizontal ? rect.width : rect.height,
              closeTo(extent, .01),
            );
          }
        }
      }
      await tester.binding.setSurfaceSize(null);
    },
  );
}
