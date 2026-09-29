import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/harmony_adapt/widgets/harmony_loading.dart';
import 'package:PiliPlus/harmony_adapt/widgets/cached_navigation_view.dart';

void main() {
  testWidgets('loading fades in even when initially fully requested', (
    tester,
  ) async {
    Widget app(double opacity) => MaterialApp(
      home: Center(child: HarmonyLoadingIndicator(opacity: opacity, value: .5)),
    );
    double alpha() => tester
        .widget<Opacity>(
          find.descendant(
            of: find.byType(HarmonyLoadingIndicator),
            matching: find.byType(Opacity),
          ),
        )
        .opacity;
    await tester.pumpWidget(app(1));
    expect(alpha(), 0);
    await tester.pump(const Duration(milliseconds: 110));
    expect(alpha(), inExclusiveRange(0, 1));
    await tester.pump(const Duration(milliseconds: 120));
    expect(alpha(), 1);
    await tester.pumpWidget(app(.25));
    expect(alpha(), .25);
    await tester.pumpWidget(app(0));
    expect(alpha(), 0);
  });
  testWidgets('navigation switches immediately and retains visited tabs', (
    tester,
  ) async {
    Widget app(int index) => MaterialApp(
      home: CachedNavigationView(
        index: index,
        children: const [Text('home'), Text('dynamic'), Text('mine')],
      ),
    );
    await tester.pumpWidget(app(0));
    expect(find.text('mine'), findsNothing);
    await tester.pumpWidget(app(1));
    expect(find.text('dynamic'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(CachedNavigationView),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );
    await tester.pumpWidget(app(2));
    await tester.pumpAndSettle();
    expect(find.text('mine'), findsOneWidget);
    expect(find.text('dynamic'), findsNothing);
    await tester.pumpWidget(app(0));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
