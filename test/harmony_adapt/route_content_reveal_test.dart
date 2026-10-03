import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/pages/video/widgets/route_content_reveal.dart';

void main() {
  testWidgets(
    'loaded panels build only after entrance and fade without resizing',
    (tester) async {
      final key = GlobalKey<NavigatorState>();
      final ready = ValueNotifier(false);
      addTearDown(ready.dispose);
      var builds = 0;
      await tester.pumpWidget(
        MaterialApp(navigatorKey: key, home: const SizedBox()),
      );
      key.currentState!.push(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (_, __, ___) => Center(
            child: SizedBox(
              key: const ValueKey('bounds'),
              width: 300,
              height: 500,
              child: ValueListenableBuilder<bool>(
                valueListenable: ready,
                builder: (_, value, __) => RouteContentReveal(
                  ready: value,
                  builder: (_) {
                    builds++;
                    return const Text('details');
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      ready.value = true;
      await tester.pump(const Duration(milliseconds: 120));
      expect(builds, 0);
      expect(
        tester.getSize(find.byKey(const ValueKey('bounds'))),
        const Size(300, 500),
      );
      await tester.pump(const Duration(milliseconds: 181));
      await tester.pump();
      expect(builds, greaterThan(0));
      final fade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.text('details'),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, 0);
      await tester.pump(const Duration(milliseconds: 90));
      expect(fade.opacity.value, inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(fade.opacity.value, 1);
      expect(
        tester.getSize(find.byKey(const ValueKey('bounds'))),
        const Size(300, 500),
      );
    },
  );

  testWidgets('early return cancels deferred player and panel presentation', (
    tester,
  ) async {
    final key = GlobalKey<NavigatorState>();
    Future<bool>? entered;
    var builds = 0;
    await tester.pumpWidget(
      MaterialApp(navigatorKey: key, home: const SizedBox()),
    );
    key.currentState!.push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, _, __) {
          entered = waitForVideoEntrance(context);
          return RouteContentReveal(
            ready: true,
            builder: (_) {
              builds++;
              return const Text('details');
            },
          );
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    key.currentState!.pop();
    await tester.pumpAndSettle();
    expect(await entered, false);
    expect(builds, 0);
    expect(tester.takeException(), isNull);
  });
}
