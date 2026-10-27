import 'package:PiliPlus/harmony_adapt/widgets/native_top_hit_test_guard.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native vp height converts to Flutter scaled logical coordinates', () {
    for (final scale in [1.0, 1.3, 1.5]) {
      expect(
        NativeTopHitTestGuard.extent(
          hideTopBar: false,
          collapsed: true,
          scaleFactor: scale,
        ),
        144 / scale,
      );
      expect(
        NativeTopHitTestGuard.extent(
          hideTopBar: true,
          collapsed: false,
          scaleFactor: scale,
        ),
        144 / scale,
      );
      expect(
        NativeTopHitTestGuard.extent(
          hideTopBar: true,
          collapsed: true,
          scaleFactor: scale,
        ),
        80 / scale,
      );
    }
  });

  testWidgets(
    'fixed shield rejects duplicate native tab touches after feed scroll',
    (tester) async {
      tester.view.devicePixelRatio = 2.875;
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(3184, 2232);
      addTearDown(tester.view.resetPhysicalSize);
      for (final scale in [1.0, 1.3]) {
        final scroll = ScrollController();
        var taps = 0;
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: NativeTopHitTestGuard(
              active: true,
              hideTopBar: true,
              collapsed: false,
              scaleFactor: scale,
              child: ListView.builder(
                controller: scroll,
                itemCount: 40,
                itemExtent: 200,
                itemBuilder: (_, index) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => taps++,
                  child: Text('video $index'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        scroll.jumpTo(600);
        await tester.pump();
        final size = tester.getSize(find.byType(ListView));
        final extent = 144 / scale;
        // Actual simulator native "热门" click reported at physical (1325,311).
        await tester.tapAt(
          Offset(1325 / (2.875 * scale), 311 / (2.875 * scale)),
        );
        await tester.pump();
        expect(
          taps,
          0,
          reason: 'native category tap must not open the video beneath it',
        );
        await tester.tapAt(Offset(80, extent - 1));
        await tester.pump();
        expect(taps, 0);
        await tester.tapAt(Offset(80, extent + 24));
        await tester.pump();
        expect(
          taps,
          1,
          reason:
              'visible feed immediately below the native header stays interactive',
        );
        await tester.dragFrom(Offset(80, extent + 60), const Offset(0, -100));
        await tester.pumpAndSettle();
        expect(scroll.offset, greaterThan(600));
        expect(taps, 1, reason: 'scroll is not converted to a card tap');
        expect(
          tester.getSize(find.byType(ListView)),
          size,
          reason: 'guard reserves no layout space',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        scroll.dispose();
      }
    },
  );

  testWidgets(
    'collapse mirrors native height; inactive header blocks no feed touches',
    (tester) async {
      var active = true, collapsed = false, hideTopBar = true;
      var scale = 1.0, taps = 0;
      late StateSetter update;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: StatefulBuilder(
            builder: (_, setState) {
              update = setState;
              return NativeTopHitTestGuard(
                active: active,
                hideTopBar: hideTopBar,
                collapsed: collapsed,
                scaleFactor: scale,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => taps++,
                  child: const SizedBox.expand(),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final absorber = find.byType(AbsorbPointer);
      expect(tester.getSize(absorber).height, 144);
      update(() => collapsed = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getSize(absorber).height, inExclusiveRange(80, 144));
      await tester.pumpAndSettle();
      expect(tester.getSize(absorber).height, 80);
      await tester.tapAt(const Offset(20, 79));
      await tester.tapAt(const Offset(20, 81));
      expect(taps, 1);
      update(() => hideTopBar = false);
      await tester.pumpAndSettle();
      expect(
        tester.getSize(absorber).height,
        144,
        reason: 'hideTopBar off ignores a stale collapsed flag',
      );
      update(() => scale = 1.3);
      await tester.pump();
      expect(
        tester.getSize(absorber).height,
        closeTo(144 / 1.3, .001),
        reason: 'scale changes must match native geometry immediately',
      );
      update(() => active = false);
      await tester.pump();
      expect(absorber, findsNothing);
      await tester.tapAt(const Offset(20, 20));
      expect(taps, 2, reason: 'no native header means no invisible dead zone');
      expect(tester.takeException(), isNull);
    },
  );
}
