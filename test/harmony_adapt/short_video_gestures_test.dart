import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/pages/video/shorts/pager.dart';
import 'package:PiliPlus/pages/video/shorts/session.dart';
import 'package:PiliPlus/pages/video/shorts/gestures.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(900, 640)]) {
    testWidgets(
      'pull down refreshes first video; seek and vertical paging stay independent at $size',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var refreshes = 0;
        var seeks = 0;
        final playerKey = GlobalKey();
        final session = ShortVideoSession(
          initial: const ShortVideoEntry(bvid: 'a'),
          loadRelated: (_) async => const [ShortVideoEntry(bvid: 'b')],
          loadFresh: () async {
            refreshes++;
            return const [
              ShortVideoEntry(bvid: 'new'),
              ShortVideoEntry(bvid: 'second'),
            ];
          },
          play: (_) async => true,
        );
        Widget build({bool enabled = true}) => MaterialApp(
          home: Scaffold(
            body: ShortVideoPager(
              session: session,
              enabled: enabled,
              builder: (_, index, active) => active
                  ? _SeekFixture(key: playerKey, onSeek: () => seeks++)
                  : const ColoredBox(color: Colors.black),
            ),
          ),
        );
        await tester.pumpWidget(build());
        await tester.pumpAndSettle();
        final original = playerKey.currentState;
        await tester.drag(
          find.byType(_SeekFixture),
          Offset(size.width * .55, 0),
        );
        await tester.pumpAndSettle();
        expect(seeks, 1);
        expect(session.index, 0);
        expect(refreshes, 0);
        // First video: hand moves DOWN, replaces both list and first source.
        await tester.drag(find.byType(_SeekFixture), const Offset(0, 220));
        await tester.pumpAndSettle();
        expect(refreshes, 1);
        expect(session.current.bvid, 'new');
        expect(session.entries.map((e) => e.bvid), ['new', 'second']);
        expect(playerKey.currentState, same(original));
        // Moving UP always selects the next video, including at index zero.
        await tester.drag(
          find.byType(_SeekFixture),
          Offset(0, -size.height * .75),
        );
        await tester.pumpAndSettle();
        expect(session.index, 1);
        expect(refreshes, 1);
        expect(seeks, 1);
        await tester.drag(
          find.byType(_SeekFixture),
          Offset(0, size.height * .75),
        );
        await tester.pumpAndSettle();
        expect(session.index, 0);
        expect(refreshes, 1);
        await tester.pumpWidget(build(enabled: false));
        await tester.drag(find.byType(_SeekFixture), const Offset(0, 220));
        await tester.pumpAndSettle();
        expect(refreshes, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        session.dispose();
      },
    );
  }
}

class _SeekFixture extends StatefulWidget {
  const _SeekFixture({super.key, required this.onSeek});
  final VoidCallback onSeek;
  @override
  State<_SeekFixture> createState() => _SeekFixtureState();
}

class _SeekFixtureState extends State<_SeekFixture> {
  late final gestures = ShortVideoGestures(
    onTap: () {},
    onDoubleTap: () {},
    leftAction: () => ShortSwipeAction.seek,
    rightAction: () => ShortSwipeAction.seek,
    onSeekStart: () {},
    onSeekUpdate: (_) {},
    onSeekEnd: () => widget.onSeek(),
    onSeekCancel: () {},
    onNavigate: (_) {},
  );
  final longPress = LongPressGestureRecognizer()..onLongPressStart = ((_) {});
  @override
  void dispose() {
    gestures.dispose();
    longPress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (event) {
      gestures.addPointer(event);
      longPress.addPointer(event);
    },
    child: const ColoredBox(color: Colors.black, child: SizedBox.expand()),
  );
}
