import 'dart:async';
import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart'
    as refresh;
import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:PiliPlus/harmony_adapt/widgets/harmony_loading.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/memory_box.dart';

void main() {
  setUpAll(() => GStorage.setting = MemoryBox());
  for (final width in [1008.0, 2048.0, 3184.0]) {
    testWidgets('64vp release refresh and fade before return at $width', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 2.875;
      tester.view.physicalSize = Size(width, 2232);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      var calls = 0;
      var done = Completer<void>();
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
              child: ListView.builder(
                physics: const ClampingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                itemExtent: 80,
                itemCount: 40,
                itemBuilder: (_, i) => Text('row $i'),
              ),
            ),
          ),
        ),
      );
      final top = tester.getTopLeft(find.text('row 0')).dy;
      final light = await tester.startGesture(const Offset(120, 200));
      await light.moveBy(const Offset(0, 40));
      await tester.pump();
      double opacity() => tester
          .widget<HarmonyLoadingIndicator>(
            find.byKey(const ValueKey('harmony-refresh-opacity')),
          )
          .opacity;
      final reveal = find.byKey(const ValueKey('harmony-refresh-reveal'));
      final loader = find.byType(HarmonyLoadingIndicator);
      final headerRect = tester.getRect(reveal);
      final loaderRect = tester.getRect(loader);
      expect(tester.widget<ClipRect>(reveal).clipBehavior, Clip.hardEdge);
      expect(
        headerRect.height,
        closeTo(tester.getTopLeft(find.text('row 0')).dy - top, .01),
      );
      expect(
        loaderRect.height,
        24,
        reason: 'Do not resize the native platform view during pull',
      );
      expect(
        loaderRect.top,
        lessThan(headerRect.top),
        reason: 'A light pull must still be masked, not just transparent',
      );
      expect(loaderRect.intersect(headerRect).height, lessThan(24));
      final firstOpacity = opacity();
      expect(firstOpacity, inExclusiveRange(0, 1));
      await light.moveBy(const Offset(0, 10));
      await tester.pump();
      expect(opacity(), greaterThan(firstOpacity));
      expect(opacity(), lessThan(1));
      await light.up();
      await tester.pumpAndSettle();
      expect(calls, 0, reason: 'A small accidental pull is below threshold');
      final pull = await tester.startGesture(const Offset(120, 200));
      await pull.moveBy(const Offset(0, 220));
      await tester.pump();
      expect(tester.getTopLeft(find.text('row 0')).dy, greaterThan(top + 96));
      final loadingElement = tester.element(
        find.byType(HarmonyLoadingIndicator),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(calls, 0);
      expect(find.byType(RefreshProgressIndicator), findsNothing);
      final releasedOffset = tester.getTopLeft(find.text('row 0')).dy;
      await pull.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final nextOffset = tester.getTopLeft(find.text('row 0')).dy;
      expect((nextOffset - releasedOffset).abs(), lessThan(12));
      expect(nextOffset, greaterThan(top + 64));
      expect(calls, 0);
      for (var frame = 0; frame < 90; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(calls, 1);
      expect(
        tester.element(find.byType(HarmonyLoadingIndicator)),
        same(loadingElement),
        reason: 'Release must not remount the native loader',
      );
      expect(tester.getTopLeft(find.text('row 0')).dy, closeTo(top + 64, 1));
      expect(
        tester.getRect(loader).intersect(tester.getRect(reveal)).height,
        closeTo(24, .01),
      );
      final duplicate = key.currentState!.show();
      await tester.pump();
      expect(calls, 1);
      done.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final fadingOpacity = opacity();
      expect(fadingOpacity, inExclusiveRange(0, 1));
      await tester.pump(const Duration(milliseconds: 100));
      expect(opacity(), lessThan(fadingOpacity));
      expect(tester.getTopLeft(find.text('row 0')).dy, closeTo(top + 64, 1));
      await tester.pumpAndSettle();
      await duplicate;
      expect(tester.getTopLeft(find.text('row 0')).dy, closeTo(top, 1));
      expect(find.byType(HarmonyLoadingIndicator), findsNothing);
      done = Completer<void>();
      final manual = key.currentState!.show();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(calls, 2);
      done.complete();
      await manual;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
