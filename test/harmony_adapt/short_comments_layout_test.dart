import 'package:PiliPlus/pages/video/shorts/loading_grace.dart';
import 'package:PiliPlus/pages/video/shorts/comments_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'cache handoff has no loading flash; real stalls keep loading and retry available',
    (tester) async {
      var taps = 0;
      Widget loading(String key) => MaterialApp(
        home: ShortLoadingGrace(
          key: ValueKey(key),
          child: TextButton(onPressed: () => taps++, child: const Text('加载中')),
        ),
      );
      await tester.pumpWidget(loading('a'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('加载中'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(loading('b'));
      await tester.pump(const Duration(milliseconds: 310));
      expect(find.text('加载中'), findsOneWidget);
      await tester.tap(find.text('加载中'));
      expect(taps, 1);
      await tester.pumpWidget(loading('c'));
      expect(find.text('加载中'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'comments reveal without covering or recreating video on phone and fold; reverse is stable',
    (tester) async {
      for (final size in [
        const Size(390, 844),
        const Size(840, 800),
        const Size(600, 320),
      ]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        final player = GlobalKey<_VideoState>();
        var open = false;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return ShortCommentsLayout(
                  panel: open
                      ? const ColoredBox(
                          key: ValueKey('comments'),
                          color: Colors.grey,
                        )
                      : null,
                  builder: (_, compact) => _Video(key: player),
                );
              },
            ),
          ),
        );
        final state = player.currentState;
        update(() => open = true);
        await tester.pumpAndSettle();
        expect(player.currentState, same(state));
        final video = tester.getRect(find.byType(_Video));
        final comments = tester.getRect(find.byKey(const ValueKey('comments')));
        expect(video.overlaps(comments), isFalse);
        if (size.width >= 720) {
          expect(video.right, comments.left);
        } else {
          expect(video.bottom, comments.top);
        }
        update(() => open = false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 70));
        update(() => open = true);
        await tester.pumpAndSettle();
        expect(player.currentState, same(state));
        update(() => open = false);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('comments')), findsNothing);
        expect(tester.getSize(find.byType(_Video)), size);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );
}

class _Video extends StatefulWidget {
  const _Video({super.key});
  @override
  State<_Video> createState() => _VideoState();
}

class _VideoState extends State<_Video> {
  @override
  Widget build(BuildContext context) => const ColoredBox(color: Colors.black);
}
