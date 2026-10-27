import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show HorizontalDragGestureRecognizer;
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/common/widgets/video_card/deferred_navigation_guard.dart';
import 'package:PiliPlus/common/widgets/flutter/page/tabs.dart' as paging;

void main() {
  testWidgets(
    'one pending lookup navigates once when the card remains current',
    (tester) async {
      final result = Completer<void>();
      var lookups = 0;
      var opened = 0;
      Future<void>? work;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    work = runGuardedNavigation(context, (current) async {
                      lookups++;
                      await result.future;
                      if (current()) opened++;
                    }),
                child: const Text('video'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('video'));
      await tester.tap(find.text('video'));
      expect(lookups, 1);
      result.complete();
      await work;
      expect(opened, 1);
    },
  );
  testWidgets(
    'covered route cancels the lookup even if the user returns before it completes',
    (tester) async {
      final nav = GlobalKey<NavigatorState>();
      final result = Completer<void>();
      var opened = 0;
      Future<void>? work;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    work = runGuardedNavigation(context, (current) async {
                      await result.future;
                      if (current()) opened++;
                    }),
                child: const Text('video'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('video'));
      nav.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('other page')),
        ),
      );
      await tester.pumpAndSettle();
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      result.complete();
      await work;
      expect(opened, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('unmounted card cannot push when its lookup finishes', (
    tester,
  ) async {
    final result = Completer<void>();
    var opened = 0;
    Future<void>? work;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  work = runGuardedNavigation(context, (current) async {
                    await result.future;
                    if (current()) opened++;
                  }),
              child: const Text('video'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('video'));
    await tester.pumpWidget(const SizedBox());
    result.complete();
    await work;
    expect(opened, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('inactive root page cancels lookup even when reactivated later', (
    tester,
  ) async {
    final result = Completer<void>();
    var opened = 0;
    var active = true;
    Future<void>? work;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (_, setState) {
              update = setState;
              return TickerMode(
                enabled: active,
                child: Builder(
                  builder: (context) => TextButton(
                    onPressed: () =>
                        work = runGuardedNavigation(context, (current) async {
                          await result.future;
                          if (current()) opened++;
                        }),
                    child: const Text('video'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('video'));
    update(() => active = false);
    await tester.pump();
    update(() => active = true);
    await tester.pump();
    result.complete();
    await work;
    expect(opened, 0);
  });
  for (final local in [false, true]) {
    testWidgets(
      'late lookup never navigates after ${local ? 'local' : 'SDK'} tab switching',
      (tester) async {
        final tabs = TabController(length: 2, vsync: tester);
        final result = Completer<void>();
        var opened = 0;
        Future<void>? work;
        final source = Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () =>
                  work = runGuardedNavigation(context, (current) async {
                    await result.future;
                    if (current()) opened++;
                  }),
              child: const Text('video'),
            ),
          ),
        );
        final children = [source, const Center(child: Text('other tab'))];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: local
                  ? paging.TabBarView<HorizontalDragGestureRecognizer>(
                      controller: tabs,
                      horizontalDragGestureRecognizer:
                          HorizontalDragGestureRecognizer.new,
                      children: children,
                    )
                  : TabBarView(controller: tabs, children: children),
            ),
          ),
        );
        await tester.tap(find.text('video'));
        tabs.animateTo(1);
        await tester.pumpAndSettle();
        result.complete();
        await work;
        expect(opened, 0);
        await tester.pumpWidget(const SizedBox());
        tabs.dispose();
      },
    );
  }
}
