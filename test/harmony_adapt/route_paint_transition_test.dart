import 'package:PiliPlus/harmony_adapt/harmony_motion.dart';
import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:PiliPlus/harmony_adapt/widgets/harmony_route_transition.dart';
import 'package:PiliPlus/pages/whisper/message_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _PaintCounts {
  int builds = 0;
  int layouts = 0;
  int paints = 0;

  (int, int, int) get totals => (builds, layouts, paints);
}

class _CountedBox extends SingleChildRenderObjectWidget {
  const _CountedBox(this.counts, {required super.child});
  final _PaintCounts counts;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderCountedBox(counts);
}

class _RenderCountedBox extends RenderProxyBox {
  _RenderCountedBox(this.counts);
  final _PaintCounts counts;
  @override
  void performLayout() {
    counts.layouts++;
    super.performLayout();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    counts.paints++;
    super.paint(context, offset);
  }
}

class _CountedAnimation extends Animation<double> {
  _CountedAnimation(this.delegate);
  final Animation<double> delegate;
  final callbacks = <VoidCallback>{};
  @override
  double get value => delegate.value;
  @override
  AnimationStatus get status => delegate.status;
  @override
  void addListener(VoidCallback listener) {
    callbacks.add(listener);
    delegate.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    callbacks.remove(listener);
    delegate.removeListener(listener);
  }

  @override
  void addStatusListener(AnimationStatusListener listener) =>
      delegate.addStatusListener(listener);
  @override
  void removeStatusListener(AnimationStatusListener listener) =>
      delegate.removeStatusListener(listener);
}

class _InteractiveRoute extends GetPageRoute<void> {
  _InteractiveRoute({required super.page});

  void setGestureProgress(double progress) => controller!.value = progress;
}

void main() {
  for (final width in [412.0, 836.0, 1108.0]) {
    testWidgets(
      'route paint moves without rebuild/layout/child repaint at $width',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 700);
        addTearDown(tester.view.reset);
        final navigator = GlobalKey<NavigatorState>();
        const previous = ValueKey('previous-page');
        const incoming = ValueKey('incoming-page');
        final previousCounts = _PaintCounts();
        final incomingCounts = _PaintCounts();

        PageRouteBuilder<void> page(Key key, _PaintCounts counts) {
          late final PageRouteBuilder<void> route;
          route = PageRouteBuilder<void>(
            transitionDuration: HarmonyMotion.duration,
            reverseTransitionDuration: HarmonyMotion.duration,
            pageBuilder: (context, _, _) => Builder(
              builder: (context) {
                counts.builds++;
                return _CountedBox(
                  counts,
                  child: ColoredBox(color: Colors.white, key: key),
                );
              },
            ),
            transitionsBuilder: (context, animation, secondary, child) =>
                const HarmonyPageTransitionsBuilder().buildTransitions(
                  route,
                  context,
                  animation,
                  secondary,
                  child,
                ),
          );
          return route;
        }

        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigator,
            onGenerateRoute: (_) => page(previous, previousCounts),
          ),
        );
        await tester.pumpAndSettle();
        final route = page(incoming, incomingCounts);
        final nav = navigator.currentState!..push(route);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 30));

        final previousTotals = previousCounts.totals;
        final incomingTotals = incomingCounts.totals;
        expect(incomingCounts.builds, 1);
        expect(incomingCounts.layouts, 1);
        expect(incomingCounts.paints, 1);
        for (final element in find.byType(HarmonyRouteTransition).evaluate()) {
          expect(
            find.descendant(
              of: find.byWidget(element.widget),
              matching: find.byType(RepaintBoundary),
            ),
            findsOneWidget,
            reason: 'reuse the repaint boundary supplied by ModalRoute',
          );
        }

        void expectPositions({bool interactive = false, bool reverse = false}) {
          final coverage = HarmonyMotion.pageCoverage(
            route.animation!.value,
            interactive: interactive,
            reverse: reverse,
          );
          expect(
            tester.getTopLeft(find.byKey(incoming)).dx,
            closeTo(width * (1 - coverage), .002),
          );
          expect(
            tester.getTopLeft(find.byKey(previous)).dx,
            0,
          );
        }

        for (final ms in [25, 45, 80, 60]) {
          await tester.pump(Duration(milliseconds: ms));
          expectPositions();
        }
        nav.didStartUserGesture();
        await tester.pump();
        expectPositions(interactive: true);
        nav.didStopUserGesture();
        await tester.pump();
        expectPositions();
        expect(previousCounts.totals, previousTotals);
        expect(incomingCounts.totals, incomingTotals);

        nav.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 30));
        expectPositions(reverse: true);
        expect(previousCounts.totals, previousTotals);
        expect(incomingCounts.totals, incomingTotals);
        await tester.pumpAndSettle();
        expect(find.byKey(incoming), findsNothing);
        expect(tester.getTopLeft(find.byKey(previous)), Offset.zero);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final width in [412.0, 712.0, 1108.0]) {
    testWidgets('named Harmony routes cover fixed source pages at $width', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 760);
      addTearDown(tester.view.reset);
      addTearDown(Get.reset);
      final navigator = GlobalKey<NavigatorState>();
      final theme = ThemeData(
        platform: TargetPlatform.ohos,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {TargetPlatform.ohos: HarmonyPageTransitionsBuilder()},
        ),
      );
      Widget page(String path, {String? next}) => Scaffold(
        key: ValueKey(path),
        body: next == null
            ? Text(path)
            : TextButton(
                onPressed: () => Get.toNamed<void>(next),
                child: Text('open $next'),
              ),
      );
      await tester.pumpWidget(
        GetMaterialApp(
          navigatorKey: navigator,
          theme: theme,
          defaultTransition: Transition.native,
          initialRoute: '/',
          getPages: [
            GetPage(
              name: '/',
              page: () => page('/', next: '/search'),
            ),
            GetPage(name: '/search', page: () => page('/search')),
            GetPage(name: '/member', page: () => page('/member')),
            GetPage(name: '/fav', page: () => page('/fav')),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final nav = navigator.currentState!;

      double x(String path) => tester.getTopLeft(find.byKey(ValueKey(path))).dx;

      Future<void> coverAndReveal(String source, String target) async {
        await tester.tap(find.text('open $target'));
        await tester.pump();
        expect(x(source), 0);
        var prior = width;
        for (var i = 0; i < 3; i++) {
          await tester.pump(const Duration(milliseconds: 40));
          expect(x(source), 0);
          expect(x(target), inExclusiveRange(0, prior));
          prior = x(target);
        }
        final entryX = prior;
        await tester.pumpAndSettle();
        expect(x(target), 0);
        nav.pop();
        await tester.pump();
        prior = 0;
        for (var i = 0; i < 3; i++) {
          await tester.pump(const Duration(milliseconds: 40));
          expect(x(source), 0);
          expect(x(target), inExclusiveRange(prior, width));
          prior = x(target);
        }
        expect(entryX + prior, closeTo(width, .002));
        await tester.pumpAndSettle();
        expect(x(source), 0);
        expect(find.byKey(ValueKey(target)), findsNothing);
      }

      await coverAndReveal('/', '/search');
      nav.push(
        HarmonyMessageRoute<void>(
          page: () => page('/whisperDetail', next: '/member'),
          settings: const RouteSettings(name: '/whisperDetail'),
        ),
      );
      await tester.pumpAndSettle();
      await coverAndReveal('/whisperDetail', '/member');
      nav.pop();
      await tester.pumpAndSettle();
      nav.push(GetPageRoute<void>(page: () => page('/mine', next: '/fav')));
      await tester.pumpAndSettle();
      await coverAndReveal('/mine', '/fav');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('interactive Back follows its progress over an anchored route', (
    tester,
  ) async {
    addTearDown(Get.reset);
    final navigator = GlobalKey<NavigatorState>();
    const source = ValueKey('interactive-source');
    const incoming = ValueKey('interactive-target');
    await tester.pumpWidget(
      GetMaterialApp(
        navigatorKey: navigator,
        theme: ThemeData(
          platform: TargetPlatform.ohos,
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {TargetPlatform.ohos: HarmonyPageTransitionsBuilder()},
          ),
        ),
        defaultTransition: Transition.native,
        home: const Scaffold(key: source),
      ),
    );
    final route = _InteractiveRoute(page: () => const Scaffold(key: incoming));
    final nav = navigator.currentState!..push(route);
    await tester.pumpAndSettle();
    nav.didStartUserGesture();
    for (final progress in [.91, .65, .4, .71, .93, 1.0]) {
      route.setGestureProgress(progress);
      await tester.pump();
      if (progress < 1) {
        expect(tester.getTopLeft(find.byKey(source)).dx, 0);
      }
      expect(
        tester.getTopLeft(find.byKey(incoming)).dx,
        closeTo(800 * (1 - progress), .002),
      );
    }
    nav.didStopUserGesture();
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(incoming)).dx, 0);

    nav.didStartUserGesture();
    route.setGestureProgress(.6);
    await tester.pump();
    final releaseX = tester.getTopLeft(find.byKey(incoming)).dx;
    nav.pop();
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(incoming)).dx, releaseX);
    expect(tester.getTopLeft(find.byKey(source)).dx, 0);
    await tester.pump(const Duration(milliseconds: 45));
    expect(tester.getTopLeft(find.byKey(incoming)).dx, greaterThan(releaseX));
    expect(tester.getTopLeft(find.byKey(source)).dx, 0);
    await tester.pumpAndSettle();
    nav.didStopUserGesture();
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(source)).dx, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'gesture, hit tests and semantics use the same live translation',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final primary = AnimationController(
          vsync: tester,
          duration: HarmonyMotion.duration,
          value: .75,
        );
        final gesture = ValueNotifier(false);
        addTearDown(primary.dispose);
        addTearDown(gesture.dispose);
        var taps = 0;
        const target = ValueKey('hit-target');
        await tester.pumpWidget(
          MaterialApp(
            home: HarmonyRouteTransition(
              animation: primary,
              userGestureInProgress: gesture,
              child: Align(
                alignment: Alignment.topLeft,
                child: Semantics(
                  key: target,
                  label: 'route action',
                  button: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => taps++,
                    child: const SizedBox(width: 100, height: 80),
                  ),
                ),
              ),
            ),
          ),
        );
        gesture.value = true;
        await tester.pump();
        expect(
          tester.getTopLeft(find.byKey(target)).dx,
          closeTo(800 * (1 - .75), .002),
        );
        await tester.tap(find.byKey(target));
        expect(taps, 1);
        await tester.tapAt(const Offset(10, 30));
        expect(
          taps,
          1,
          reason: 'untranslated position must not hit the moved control',
        );
        final node = tester.getSemantics(find.byKey(target));
        var transform = Matrix4.identity();
        for (
          var ancestor = node;
          ancestor.parent != null;
          ancestor = ancestor.parent!
        ) {
          if (ancestor.transform case final Matrix4 local) {
            transform = local * transform;
          }
        }
        expect(
          MatrixUtils.transformRect(transform, node.rect).left /
              tester.view.devicePixelRatio,
          closeTo(tester.getTopLeft(find.byKey(target)).dx, .002),
        );
        gesture.value = false;
        primary.reverse();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 45));
        expect(
          tester.getTopLeft(find.byKey(target)).dx,
          closeTo(
            800 *
                (1 -
                    HarmonyMotion.pageCoverage(
                      primary.value,
                      interactive: false,
                      reverse: true,
                    )),
            .002,
          ),
        );
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'replacement and detach remove every obsolete animation listener',
    (tester) async {
      final oldPrimary = AnimationController(vsync: tester, value: .3);
      final newPrimary = AnimationController(vsync: tester, value: .8);
      final oldGesture = ValueNotifier(false),
          newGesture = ValueNotifier(false);
      final oldAnimation = _CountedAnimation(oldPrimary),
          newAnimation = _CountedAnimation(newPrimary);
      for (final controller in [oldPrimary, newPrimary]) {
        addTearDown(controller.dispose);
      }
      addTearDown(oldGesture.dispose);
      addTearDown(newGesture.dispose);
      Widget app(bool old) => MaterialApp(
        home: HarmonyRouteTransition(
          animation: old ? oldAnimation : newAnimation,
          userGestureInProgress: old ? oldGesture : newGesture,
          child: const SizedBox.expand(key: ValueKey('replacement')),
        ),
      );
      await tester.pumpWidget(app(true));
      expect(oldAnimation.callbacks.length, 1);
      await tester.pumpWidget(app(false));
      expect(oldAnimation.callbacks, isEmpty);
      expect(newAnimation.callbacks.length, 1);
      final x = tester.getTopLeft(find.byKey(const ValueKey('replacement'))).dx;
      oldPrimary.value = .9;
      oldGesture.value = true;
      await tester.pump();
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('replacement'))).dx,
        x,
      );
      newGesture.value = true;
      await tester.pump();
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('replacement'))).dx,
        closeTo(160, .002),
      );
      await tester.pumpWidget(const SizedBox());
      expect(newAnimation.callbacks, isEmpty);
      newPrimary.value = .1;
      newGesture.value = false;
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reduced motion bypasses the transition and its animation listeners',
    (tester) async {
      final primary = AnimationController(vsync: tester);
      final secondary = AnimationController(vsync: tester);
      final animation = _CountedAnimation(primary),
          cover = _CountedAnimation(secondary);
      addTearDown(primary.dispose);
      addTearDown(secondary.dispose);
      const target = ValueKey('static-page');
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Builder(
              builder: (context) =>
                  const HarmonyPageTransitionsBuilder().buildTransitions<void>(
                    MaterialPageRoute<void>(builder: (_) => const SizedBox()),
                    context,
                    animation,
                    cover,
                    const SizedBox.expand(key: target),
                  ),
            ),
          ),
        ),
      );
      expect(find.byType(HarmonyRouteTransition), findsNothing);
      expect(animation.callbacks, isEmpty);
      expect(cover.callbacks, isEmpty);
      expect(tester.getTopLeft(find.byKey(target)), Offset.zero);
      primary.value = .7;
      await tester.pump();
      expect(tester.getTopLeft(find.byKey(target)), Offset.zero);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'a zero-sized transition remains a no-op across animation updates',
    (tester) async {
      final primary = AnimationController(vsync: tester);
      addTearDown(primary.dispose);
      const target = ValueKey('zero-page');
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox.shrink(
              child: HarmonyRouteTransition(
                animation: primary,
                child: const SizedBox(key: target),
              ),
            ),
          ),
        ),
      );
      final origin = tester.getTopLeft(find.byKey(target));
      for (final value in [0.0, .3, .6, 1.0]) {
        primary.value = value;
        await tester.pump();
        expect(tester.getSize(find.byKey(target)), Size.zero);
        expect(tester.getTopLeft(find.byKey(target)), origin);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'a real route keeps arriving content live and permits an early return',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final content = ValueNotifier('loading');
      addTearDown(content.dispose);
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          theme: ThemeData(
            platform: TargetPlatform.ohos,
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.ohos: HarmonyPageTransitionsBuilder(),
              },
            ),
          ),
          home: const Scaffold(body: Text('original page')),
        ),
      );
      final route = MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          body: ValueListenableBuilder<String>(
            valueListenable: content,
            builder: (_, value, __) =>
                Text(value, key: const ValueKey('live-page')),
          ),
        ),
      );
      navigator.currentState!.push(route);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      final enteringX = tester
          .getTopLeft(find.byKey(const ValueKey('live-page')))
          .dx;
      expect(enteringX, inExclusiveRange(0, 800));
      content.value = 'ready';
      await tester.pump();
      expect(
        find.text('ready'),
        findsOneWidget,
        reason: 'no cached screenshot may freeze network results',
      );
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('live-page'))).dx,
        enteringX,
      );
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('ready'), findsNothing);
      expect(find.text('original page'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
