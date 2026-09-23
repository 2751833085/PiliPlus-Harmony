import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:PiliPlus/harmony_adapt/widgets/harmony_accent_choices.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'accent choices remain usable across native fold sizes and text scaling',
    (tester) async {
      tester.view.devicePixelRatio = 2.875;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final width in [1008.0, 2048.0, 3184.0]) {
        tester.view.physicalSize = Size(width, 2232);
        for (final dark in [false, true]) {
          var selected = 1;
          await tester.pumpWidget(
            MaterialApp(
              theme: HarmonyTheme.apply(
                dark ? ThemeData.dark() : ThemeData.light(),
                immersive: true,
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.3)),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Center(
                    child: SizedBox(
                      width: 608,
                      child: StatefulBuilder(
                        builder: (context, setState) => HarmonyAccentChoices(
                          selected: selected,
                          onSelected: (value) =>
                              setState(() => selected = value),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.text('蓝色'));
          await tester.tap(find.text('蓝色'));
          await tester.pumpAndSettle();
          expect(selected, 12);
          expect(find.byIcon(Icons.check_rounded), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      }
    },
  );
}
