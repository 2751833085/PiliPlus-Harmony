import 'package:PiliPlus/harmony_adapt/harmony_motion.dart';
import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:PiliPlus/harmony_adapt/widgets/harmony_route_transition.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

class _PaintCounts {
  int layouts = 0;
  int paints = 0;
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

void main() {
  for (final width in [412.0, 836.0, 1108.0]) {
    testWidgets(
      'route paint moves without rebuild/layout/child repaint at $width',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 700);
        addTearDown(tester.view.reset);
        final primary = AnimationController(vsync: tester);
        final secondary = AnimationController(vsync: tester);
        final counts = _PaintCounts();
        addTearDown(primary.dispose);
        addTearDown(secondary.dispose);
        const content = ValueKey('page-content');
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) =>
                  const HarmonyPageTransitionsBuilder().buildTransitions<void>(
                    MaterialPageRoute<void>(builder: (_) => const SizedBox()),
                    context,
                    primary,
                    secondary,
                    _CountedBox(
                      counts,
                      child: const SizedBox.expand(key: content),
                    ),
                  ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final layouts = counts.layouts, paints = counts.paints;
        final rebuilt = <Type>[];
        final oldCallback = debugOnRebuildDirtyWidget;
        debugOnRebuildDirtyWidget = (element, _) =>
            rebuilt.add(element.widget.runtimeType);
        try {
          for (final value in [0.0, .1, .25, .5, .8, 1.0]) {
            primary.value = value;
            await tester.pump();
            expect(
              tester.getTopLeft(find.byKey(content)).dx,
              closeTo(
                width *
                    (1 - HarmonyMotion.pageCoverage(value, interactive: false)),
                .002,
              ),
            );
          }
          secondary.value = .4;
          await tester.pump();
          expect(
            tester.getTopLeft(find.byKey(content)).dx,
            closeTo(
              -width * .2 * HarmonyMotion.pageCoverage(.4, interactive: false),
              .002,
            ),
          );
          expect(
            rebuilt,
            isEmpty,
            reason: 'animation ticks should invalidate paint, not widgets',
          );
          expect(counts.layouts, layouts);
          expect(
            counts.paints,
            paints,
            reason: 'static page paint remains retained',
          );
        } finally {
          debugOnRebuildDirtyWidget = oldCallback;
        }
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

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
        final secondary = AnimationController(vsync: tester, value: .2);
        final gesture = ValueNotifier(false);
        addTearDown(primary.dispose);
        addTearDown(secondary.dispose);
        addTearDown(gesture.dispose);
        var taps = 0;
        const target = ValueKey('hit-target');
        await tester.pumpWidget(
          MaterialApp(
            home: HarmonyRouteTransition(
              animation: primary,
              secondaryAnimation: secondary,
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
          closeTo(800 * (1 - .75 - .2 * .2), .002),
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
                    ) -
                    .2 *
                        HarmonyMotion.pageCoverage(
                          secondary.value,
                          interactive: false,
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
      final oldSecondary = AnimationController(vsync: tester);
      final newSecondary = AnimationController(vsync: tester);
      final oldGesture = ValueNotifier(false),
          newGesture = ValueNotifier(false);
      final oldAnimation = _CountedAnimation(oldPrimary),
          newAnimation = _CountedAnimation(newPrimary);
      final oldCover = _CountedAnimation(oldSecondary),
          newCover = _CountedAnimation(newSecondary);
      for (final controller in [
        oldPrimary,
        newPrimary,
        oldSecondary,
        newSecondary,
      ]) {
        addTearDown(controller.dispose);
      }
      addTearDown(oldGesture.dispose);
      addTearDown(newGesture.dispose);
      Widget app(bool old) => MaterialApp(
        home: HarmonyRouteTransition(
          animation: old ? oldAnimation : newAnimation,
          secondaryAnimation: old ? oldCover : newCover,
          userGestureInProgress: old ? oldGesture : newGesture,
          child: const SizedBox.expand(key: ValueKey('replacement')),
        ),
      );
      await tester.pumpWidget(app(true));
      expect(oldAnimation.callbacks.length, 1);
      expect(oldCover.callbacks.length, 1);
      await tester.pumpWidget(app(false));
      expect(oldAnimation.callbacks, isEmpty);
      expect(oldCover.callbacks, isEmpty);
      expect(newAnimation.callbacks.length, 1);
      expect(newCover.callbacks.length, 1);
      final x = tester.getTopLeft(find.byKey(const ValueKey('replacement'))).dx;
      oldPrimary.value = .9;
      oldSecondary.value = .7;
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
      expect(newCover.callbacks, isEmpty);
      newPrimary.value = .1;
      newSecondary.value = .5;
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
      final secondary = AnimationController(vsync: tester);
      addTearDown(primary.dispose);
      addTearDown(secondary.dispose);
      const target = ValueKey('zero-page');
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox.shrink(
              child: HarmonyRouteTransition(
                animation: primary,
                secondaryAnimation: secondary,
                child: const SizedBox(key: target),
              ),
            ),
          ),
        ),
      );
      final origin = tester.getTopLeft(find.byKey(target));
      for (final value in [0.0, .3, .6, 1.0]) {
        primary.value = value;
        secondary.value = value;
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
