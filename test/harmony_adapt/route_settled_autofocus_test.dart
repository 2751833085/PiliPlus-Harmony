import 'package:PiliPlus/harmony_adapt/harmony_motion.dart';
import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:PiliPlus/harmony_adapt/widgets/route_settled_autofocus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PageRoute<void> searchRoute(
  FocusNode node, {
  bool enabled = true,
  bool excludeFocus = false,
  Duration duration = HarmonyMotion.duration,
}) {
  late PageRoute<void> route;
  route = PageRouteBuilder<void>(
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    pageBuilder: (_, __, ___) => ExcludeFocus(
      excluding: excludeFocus,
      child: Scaffold(
        appBar: AppBar(
          title: RouteSettledAutofocus(
            enabled: enabled,
            focusNode: node,
            child: TextField(
              key: const ValueKey('search-field'),
              focusNode: node,
              autofocus: !enabled,
            ),
          ),
        ),
      ),
    ),
    transitionsBuilder: (context, animation, secondary, child) =>
        const HarmonyPageTransitionsBuilder().buildTransitions<void>(
          route,
          context,
          animation,
          secondary,
          child,
        ),
  );
  return route;
}

void main() {
  late GlobalKey<NavigatorState> nav;
  late FocusNode node;

  setUp(() {
    nav = GlobalKey<NavigatorState>();
    node = FocusNode();
  });

  tearDown(() => node.dispose());

  Future<void> mount(WidgetTester tester, {bool reduceMotion = false}) =>
      tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: reduceMotion,
            ),
            child: child!,
          ),
          home: const Scaffold(body: Text('home')),
        ),
      );

  testWidgets('IME opens only after the same 300ms push has completed', (
    tester,
  ) async {
    await mount(tester);
    tester.testTextInput.log.clear();
    var focusRequests = 0;
    node.addListener(() {
      if (node.hasFocus) focusRequests++;
    });
    final route = searchRoute(node);
    nav.currentState!.push(route);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(route.animation!.status, AnimationStatus.forward);
    expect(node.hasFocus, isFalse);
    expect(
      tester.testTextInput.log.where((call) => call.method == 'TextInput.show'),
      isEmpty,
    );
    await tester.pump(const Duration(milliseconds: 170));
    expect(node.hasFocus, isFalse);
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump();
    expect(route.animation!.status, AnimationStatus.completed);
    expect(route.transitionDuration, HarmonyMotion.duration);
    expect(route.reverseTransitionDuration, HarmonyMotion.duration);
    expect(node.hasFocus, isTrue);
    expect(focusRequests, 1);
    expect(
      tester.testTextInput.log.where((call) => call.method == 'TextInput.show'),
      isNotEmpty,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'quick back cancels focus instead of opening a leaving keyboard',
    (
      tester,
    ) async {
      await mount(tester);
      tester.testTextInput.log.clear();
      nav.currentState!.push(searchRoute(node));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      expect(node.hasFocus, isFalse);
      expect(
        tester.testTextInput.log.where(
          (call) => call.method == 'TextInput.show',
        ),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'a covered entrance waits for its own return, then focuses once',
    (
      tester,
    ) async {
      await mount(tester);
      nav.currentState!.push(searchRoute(node));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      nav.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('cover')),
        ),
      );
      await tester.pumpAndSettle();
      expect(node.hasFocus, isFalse);
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      expect(node.hasFocus, isTrue);
      node.unfocus();
      await tester.pump();
      nav.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const SizedBox()),
      );
      await tester.pumpAndSettle();
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      expect(
        node.hasFocus,
        isFalse,
        reason: 'do not override a prior dismissal',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('an explicit tap can type during entry without a second request', (
    tester,
  ) async {
    await mount(tester);
    nav.currentState!.push(searchRoute(node));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));
    // A tap is intentional input; route completion must not prevent it or later
    // reopen a keyboard the user has dismissed.
    await tester.tap(find.byKey(const ValueKey('search-field')));
    await tester.pump();
    expect(node.hasFocus, isTrue);
    await tester.enterText(find.byType(TextField), '鸿蒙');
    node.unfocus();
    await tester.pumpAndSettle();
    expect(node.hasFocus, isFalse);
    expect(find.text('鸿蒙'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'disabled wrapper leaves the existing child autofocus unchanged',
    (
      tester,
    ) async {
      await mount(tester);
      nav.currentState!.push(searchRoute(node, enabled: false));
      await tester.pump();
      await tester.pump();
      expect(node.hasFocus, isTrue);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('reduced motion and an immediate route add no artificial delay', (
    tester,
  ) async {
    await mount(tester, reduceMotion: true);
    nav.currentState!.push(searchRoute(node, duration: Duration.zero));
    await tester.pump();
    await tester.pump();
    expect(node.hasFocus, isTrue);
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('search-field')),
        matching: find.byType(FractionalTranslation),
      ),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a focus-excluded field is never force-focused', (tester) async {
    await mount(tester);
    nav.currentState!.push(searchRoute(node, excludeFocus: true));
    await tester.pumpAndSettle();
    expect(node.hasFocus, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
