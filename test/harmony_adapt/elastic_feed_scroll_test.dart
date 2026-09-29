import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart'
    as refresh;
import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:PiliPlus/harmony_adapt/widgets/harmony_loading.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'helpers/memory_box.dart';

void main() {
  setUpAll(() => GStorage.setting = MemoryBox());
  for (final width in [350.0, 712.0, 1108.0]) {
    testWidgets(
      'feed uses normal bounce, holds refresh and preserves bottom bounce at $width',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 800);
        addTearDown(tester.view.reset);
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        final done = Completer<void>();
        var calls = 0;
        final key = GlobalKey<refresh.RefreshIndicatorState>();
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(extensions: const [HarmonyStyle()]),
            home: Scaffold(
              body: refresh.RefreshIndicator(
                key: key,
                onRefresh: () {
                  calls++;
                  return done.future;
                },
                child: CustomScrollView(
                  controller: scroll,
                  slivers: [
                    SliverList.builder(
                      itemCount: 50,
                      itemBuilder: (_, i) =>
                          SizedBox(height: 80, child: Text('row $i')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        final finger = await tester.startGesture(const Offset(150, 180));
        await finger.moveBy(const Offset(0, 240));
        await tester.pump();
        expect(scroll.offset, lessThan(-72));
        expect(
          tester.getTopLeft(find.text('row 0')).dy,
          closeTo(-scroll.offset, 1),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(calls, 0, reason: 'Refresh requires release');
        await finger.up();
        for (var frame = 0; frame < 100; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(calls, 1);
        expect(tester.getTopLeft(find.text('row 0')).dy, closeTo(64, 1));
        final duplicate = key.currentState!.show();
        done.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        expect(
          tester
              .widget<HarmonyLoadingIndicator>(
                find.byType(HarmonyLoadingIndicator),
              )
              .opacity,
          inExclusiveRange(0, 1),
        );
        expect(tester.getTopLeft(find.text('row 0')).dy, closeTo(64, 1));
        await tester.pumpAndSettle();
        await duplicate;
        expect(scroll.offset, closeTo(0, 1));
        expect(tester.getTopLeft(find.text('row 0')).dy, closeTo(0, 1));
        scroll.jumpTo(scroll.position.maxScrollExtent);
        await tester.pump();
        final bottom = await tester.startGesture(const Offset(150, 500));
        await bottom.moveBy(const Offset(0, -100));
        await tester.pump();
        expect(scroll.offset, greaterThan(scroll.position.maxScrollExtent));
        await bottom.up();
        await tester.pumpAndSettle();
        expect(scroll.offset, closeTo(scroll.position.maxScrollExtent, 1));
        expect(calls, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'unarmed dragging matches an ordinary bouncing list pixel for pixel',
    (tester) async {
      Future<List<double>> offsets(bool refreshing) async {
        final controller = ScrollController();
        final list = CustomScrollView(
          controller: controller,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverList.builder(
              itemCount: 40,
              itemBuilder: (_, i) =>
                  SizedBox(height: 80, child: Text('row $i')),
            ),
          ],
        );
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey(refreshing),
            theme: ThemeData(extensions: const [HarmonyStyle()]),
            home: Scaffold(
              body: refreshing
                  ? refresh.RefreshIndicator(
                      onRefresh: () async {},
                      child: list,
                    )
                  : list,
            ),
          ),
        );
        final values = <double>[];
        var gesture = await tester.startGesture(const Offset(150, 180));
        for (var n = 0; n < 4; n++) {
          await gesture.moveBy(const Offset(0, 12));
          await tester.pump(const Duration(milliseconds: 16));
          values.add(controller.offset);
        }
        await gesture.cancel();
        await tester.pumpAndSettle();
        controller.jumpTo(500);
        await tester.pump();
        gesture = await tester.startGesture(const Offset(150, 450));
        for (var n = 0; n < 6; n++) {
          await gesture.moveBy(const Offset(0, -20));
          await tester.pump(const Duration(milliseconds: 16));
          values.add(controller.offset);
        }
        await gesture.cancel();
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
        return values;
      }

      final mine = await offsets(false);
      final feed = await offsets(true);
      for (var i = 0; i < mine.length; i++) {
        expect(feed[i], closeTo(mine[i], .01));
      }
    },
  );
  testWidgets(
    'manual refresh keeps native-header clearance and recovers after failure',
    (tester) async {
      final key = GlobalKey<refresh.RefreshIndicatorState>();
      var calls = 0;
      var done = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: const [HarmonyStyle()]),
          home: Scaffold(
            body: refresh.RefreshIndicator(
              key: key,
              edgeOffset: 120,
              onRefresh: () {
                calls++;
                return done.future;
              },
              child: CustomScrollView(
                slivers: [
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                  SliverList.builder(
                    itemCount: 25,
                    itemBuilder: (_, i) =>
                        SizedBox(height: 80, child: Text('row $i')),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final future = key.currentState!.show();
      await tester.pump();
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(calls, 1);
      expect(tester.getTopLeft(find.text('row 0')).dy, closeTo(184, 1));
      expect(
        tester.getTopLeft(find.byType(HarmonyLoadingIndicator)).dy,
        greaterThanOrEqualTo(120),
      );
      done.completeError(StateError('test request failed'));
      await tester.pumpAndSettle();
      await future;
      expect(tester.getTopLeft(find.text('row 0')).dy, closeTo(120, 1));
      done = Completer<void>();
      final retry = key.currentState!.show();
      await tester.pump();
      done.complete();
      await tester.pumpAndSettle();
      await retry;
      expect(calls, 2);
      expect(tester.takeException(), isNull);
    },
  );
}
