import 'package:get/get.dart';
import 'package:PiliPlus/pages/setting/widgets/multi_select_dialog.dart';
import 'package:PiliPlus/pages/setting/widgets/ordered_multi_select_dialog.dart';
import 'package:PiliPlus/pages/setting/widgets/dual_slider_dialog.dart';
import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:PiliPlus/pages/setting/widgets/select_dialog.dart';
import 'package:PiliPlus/pages/setting/widgets/slider_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Future<void> openSettingsDialog(
  WidgetTester tester, {
  required Widget dialog,
  required ValueChanged<Object?> onResult,
  Brightness brightness = Brightness.light,
  bool immersive = true,
  bool reducedMotion = false,
  bool highContrast = false,
}) async {
  await tester.pumpWidget(
    GetMaterialApp(
      enableLog: false,
      theme: HarmonyTheme.apply(
        ThemeData(brightness: brightness),
        immersive: immersive,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: reducedMotion,
          highContrast: highContrast,
        ),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => onResult(
              await showDialog<Object>(
                context: context,
                builder: (_) => dialog,
              ),
            ),
            child: const Text('打开设置'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开设置'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'custom selector gets one immersive finish and returns selection',
    (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        Object? result;
        await openSettingsDialog(
          tester,
          brightness: brightness,
          dialog: const SelectDialog<int>(
            title: '颜色选择',
            value: 1,
            values: [(1, '默认粉'), (2, '绿色')],
          ),
          onResult: (value) => result = value,
        );
        expect(find.byType(ImmersiveSurface), findsOneWidget);
        expect(find.byType(BackdropFilter), findsOneWidget);
        await tester.tap(find.text('绿色'));
        await tester.pumpAndSettle();
        expect(result, 2);
        expect(find.byType(SelectDialog<int>), findsNothing);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'slider uses immersive finish without changing confirm or cancel',
    (
      tester,
    ) async {
      Object? result;
      const dialog = SliderDialog(
        value: 20,
        title: Text('预览大小'),
        min: 0,
        max: 100,
      );
      await openSettingsDialog(
        tester,
        dialog: dialog,
        onResult: (value) => result = value,
      );
      expect(find.byType(ImmersiveSurface), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
      final slider = find.byType(Slider);
      await tester.drag(slider, const Offset(65, 0));
      await tester.pumpAndSettle();
      final value = tester.widget<Slider>(slider).value;
      expect(value, greaterThan(20));
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      expect(result, value);
      await openSettingsDialog(
        tester,
        dialog: dialog,
        onResult: (value) => result = value,
      );
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('immersive off, reduced motion and contrast suppress live blur', (
    tester,
  ) async {
    for (final mode in ['off', 'reduced motion', 'high contrast']) {
      await openSettingsDialog(
        tester,
        dialog: const SelectDialog<int>(
          title: '选择',
          value: 1,
          values: [(1, '第一项'), (2, '第二项')],
        ),
        immersive: mode != 'off',
        reducedMotion: mode == 'reduced motion',
        highContrast: mode == 'high contrast',
        onResult: (_) {},
      );
      expect(find.byType(BackdropFilter), findsNothing, reason: mode);
      expect(
        find.byType(ImmersiveSurface),
        mode == 'off' ? findsNothing : findsOneWidget,
        reason: mode,
      );
      await tester.tap(find.text('第二项'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: mode);
    }
  });
  testWidgets(
    'multiple selectors keep selection order and confirmation results',
    (tester) async {
      Object? result;
      for (final ordered in [false, true]) {
        await openSettingsDialog(
          tester,
          dialog: ordered
              ? const OrderedMultiSelectDialog<int>(
                  title: '顺序选择',
                  initValues: [1],
                  values: {1: '第一项', 2: '第二项'},
                )
              : const MultiSelectDialog<int>(
                  title: '多项选择',
                  initValues: [1],
                  values: {1: '第一项', 2: '第二项'},
                ),
          onResult: (value) => result = value,
        );
        expect(find.byType(ImmersiveSurface), findsOneWidget);
        expect(find.byType(BackdropFilter), findsOneWidget);
        await tester.tap(find.text('第二项'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('确定'));
        await tester.pumpAndSettle();
        expect((result as Iterable<int>).toList(), [1, 2]);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('dual slider retains both independent values and cancel result', (
    tester,
  ) async {
    Object? result;
    const dialog = DualSliderDialog(
      title: Text('双滑块'),
      description1: Text('上限'),
      description2: Text('下限'),
      value1: 20,
      value2: 80,
      min: 0,
      max: 100,
    );
    await openSettingsDialog(
      tester,
      dialog: dialog,
      onResult: (value) => result = value,
    );
    expect(find.byType(ImmersiveSurface), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);
    final sliders = find.byType(Slider);
    await tester.drag(sliders.first, const Offset(45, 0));
    await tester.pumpAndSettle();
    final values = tester
        .widgetList<Slider>(sliders)
        .map((slider) => slider.value)
        .toList();
    expect(values.first, greaterThan(20));
    expect(values.last, 80);
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(result, (values.first, values.last));
    await openSettingsDialog(
      tester,
      dialog: dialog,
      onResult: (value) => result = value,
    );
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(tester.takeException(), isNull);
  });
}
