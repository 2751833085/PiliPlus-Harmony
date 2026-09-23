import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:PiliPlus/pages/setting/widgets/popup_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'value menus stay by their row, retain selection and respect light material preferences',
    (tester) async {
      tester.view.devicePixelRatio = 2.875;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final pixels in [
        const Size(1008, 2232),
        const Size(2048, 2232),
        const Size(3184, 2232),
      ]) {
        tester.view.physicalSize = pixels;
        for (final dark in [false, true]) {
          for (final immersive in [false, true]) {
            var selected = 0;
            await tester.pumpWidget(
              MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(1.3)),
                  child: child!,
                ),
                theme: HarmonyTheme.apply(
                  dark ? ThemeData.dark() : ThemeData.light(),
                  immersive: immersive,
                ),
                home: Scaffold(
                  body: Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        top: 100,
                        left: 16,
                        right: 16,
                      ),
                      child: SizedBox(
                        width: 320,
                        child: PopupListTile<int>(
                          title: const Text('Palette'),
                          value: () => (selected, 'Choice $selected'),
                          itemBuilder: (_) => [
                            for (var i = 0; i < 3; i++)
                              PopupMenuItem(value: i, child: Text('Option $i')),
                          ],
                          onSelected: (value, refresh) {
                            selected = value;
                            refresh();
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.text('Palette'));
            await tester.pumpAndSettle();
            expect(find.byType(BottomSheet), findsNothing);
            final first = tester.getRect(find.text('Option 0'));
            expect(
              first.top,
              lessThan(240),
              reason: 'menu should stay near its row',
            );
            expect(first.left, greaterThanOrEqualTo(0));
            expect(
              tester.getRect(find.text('Option 2')).bottom,
              lessThan(pixels.height / 2.875),
            );
            expect(
              find.byType(BackdropFilter),
              immersive ? findsWidgets : findsNothing,
            );
            await tester.tap(find.text('Option 2'));
            await tester.pumpAndSettle();
            expect(selected, 2);
            expect(find.text('Choice 2'), findsOneWidget);
            await tester.tap(find.text('Palette'));
            await tester.pumpAndSettle();
            await tester.binding.handlePopRoute();
            await tester.pumpAndSettle();
            expect(find.text('Palette'), findsOneWidget);
            expect(find.text('Option 2'), findsNothing);
            expect(selected, 2);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
          }
        }
      }
    },
  );
}
