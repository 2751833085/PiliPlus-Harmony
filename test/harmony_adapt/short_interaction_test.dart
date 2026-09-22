import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/pages/video/shorts/gestures.dart';
import 'package:PiliPlus/pages/video/shorts/chrome.dart';

void main() {
  testWidgets(
    'single tap hides chrome; double tap toggles playback once without hiding or liking',
    (tester) async {
      final key = GlobalKey<_HarnessState>();
      await tester.pumpWidget(MaterialApp(home: _Harness(key: key)));
      final state = key.currentState!;
      final surface = find.byKey(const ValueKey('video'));
      await tester.tap(surface);
      await tester.pump(const Duration(milliseconds: 350));
      expect(state.visible, isFalse);
      expect(state.plays, 0);
      await tester.tap(surface);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(surface);
      await tester.pump(const Duration(milliseconds: 350));
      expect(state.visible, isFalse);
      expect(state.plays, 1);
      await tester.tap(surface);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(surface);
      await tester.pump(const Duration(milliseconds: 350));
      expect(state.plays, 2);
      for (final dx in [-180.0, 180.0]) {
        await tester.drag(surface, Offset(dx, 0));
        await tester.pumpAndSettle();
      }
      expect(state.seeks, 2);
      expect(state.routes, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'independent custom left/right actions never start seeking; short and cancelled drags do nothing',
    (tester) async {
      final key = GlobalKey<_HarnessState>();
      await tester.pumpWidget(MaterialApp(home: _Harness(key: key)));
      final state = key.currentState!;
      state.left = ShortSwipeAction.comments;
      state.right = ShortSwipeAction.author;
      final surface = find.byKey(const ValueKey('video'));
      await tester.drag(surface, const Offset(-180, 0));
      await tester.pumpAndSettle();
      await tester.drag(surface, const Offset(180, 0));
      await tester.pumpAndSettle();
      expect(state.routes, [
        ShortSwipeAction.comments,
        ShortSwipeAction.author,
      ]);
      expect(state.seeks, 0);
      await tester.drag(surface, const Offset(42, 0));
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(tester.getCenter(surface));
      await gesture.moveBy(const Offset(-180, 0));
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(state.routes.length, 2);
      expect(state.seeks, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'hidden chrome does not intercept touches; minimal playback button handles a double tap once',
    (tester) async {
      var hidden = 0, play = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: [
                ShortVideoChrome(
                  visible: false,
                  child: TextButton(
                    onPressed: () => hidden++,
                    child: const Text('作者简介'),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 0,
                  child: ShortVideoMinimalControls(
                    playing: false,
                    time: '00:10 / 02:30',
                    progress: const SizedBox(height: 8),
                    onToggle: () => play++,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('作者简介'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(hidden, 0);
      final icon = find.byIcon(Icons.play_arrow_rounded);
      await tester.tap(icon);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(icon);
      await tester.pump(const Duration(milliseconds: 350));
      expect(play, 1);
      expect(find.text('00:10 / 02:30'), findsOneWidget);
    },
  );
}

class _Harness extends StatefulWidget {
  const _Harness({super.key});
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  bool visible = true;
  int plays = 0, seeks = 0;
  ShortSwipeAction left = ShortSwipeAction.seek, right = ShortSwipeAction.seek;
  final routes = <ShortSwipeAction>[];
  late final gestures = ShortVideoGestures(
    onTap: () => visible = !visible,
    onDoubleTap: () => plays++,
    leftAction: () => left,
    rightAction: () => right,
    onSeekStart: () => seeks++,
    onSeekUpdate: (_) {},
    onSeekEnd: () {},
    onSeekCancel: () {},
    onNavigate: routes.add,
  );
  @override
  void dispose() {
    gestures.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: gestures.addPointer,
    child: const ColoredBox(
      key: ValueKey('video'),
      color: Colors.black,
      child: SizedBox.expand(),
    ),
  );
}
