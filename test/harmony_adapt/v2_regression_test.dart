import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:PiliPlus/harmony_adapt/toast_layout.dart';
import 'package:PiliPlus/harmony_adapt/window_layout.dart';
import 'package:PiliPlus/harmony_adapt/widgets/harmony_loading.dart';
import 'package:PiliPlus/harmony_adapt/widgets/harmony_settings_list.dart';
import 'package:PiliPlus/harmony_adapt/widgets/harmony_switch.dart';
import 'package:PiliPlus/common/widgets/loading_widget/m3e_loading_indicator.dart';
import 'package:PiliPlus/models_new/video/video_ai_conclusion/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('floating Dock survives single, double and triple display widths', () {
    for (final width in [320.0, 599.0, 600.0, 840.0, 1200.0]) {
      expect(
        HarmonyWindowLayout.useBottomNavigation(
          width,
          keepDock: true,
          sideBar: true,
        ),
        isTrue,
      );
    }
    expect(HarmonyWindowLayout.useBottomNavigation(840), isFalse);
    expect(HarmonyWindowLayout.useSettingsSplit(900, 1), isTrue);
    expect(HarmonyWindowLayout.useSettingsSplit(900, 1.5), isFalse);
  });

  test('toast clears native Dock, scaled viewport and keyboard', () {
    expect(
      HarmonyToastLayout.bottom(
        safeBottom: 24,
        keyboardBottom: 0,
        dockBottom: 80,
      ),
      96,
    );
    expect(
      HarmonyToastLayout.bottom(
        safeBottom: 24,
        keyboardBottom: 0,
        dockBottom: 80,
        scale: .8,
      ),
      116,
    );
    expect(
      HarmonyToastLayout.bottom(
        safeBottom: 24,
        keyboardBottom: 300,
        dockBottom: 80,
      ),
      324,
    );
    expect(
      HarmonyToastLayout.bottom(
        safeBottom: 24,
        keyboardBottom: 0,
        dockBottom: 0,
      ),
      48,
    );
  });

  test(
    'AI preserves delivered text and distinguishes generation from no content',
    () {
      final available = AiConclusionData.fromJson({
        'code': 1,
        'model_result': {'summary': 'Summary', 'result_type': 1},
      });
      expect(available.hasContent, isTrue);
      expect(available.isGenerating, isFalse);
      final absent = AiConclusionData.fromJson({
        'code': 1,
        'stid': '',
        'model_result': {'summary': '', 'outline': [], 'result_type': 0},
      });
      expect(absent.hasContent, isFalse);
      expect(absent.isGenerating, isTrue);
      expect(absent.unavailableMessage, contains('超时'));
      expect(
        AiConclusionData.fromJson({
          'code': 0,
          'model_result': {'summary': '  '},
        }).hasContent,
        isFalse,
      );
      expect(
        AiConclusionData.fromJson({'code': -1}).unavailableMessage,
        contains('不支持'),
      );
    },
  );

  testWidgets('existing loader switches style and reduced motion stops ticks', (
    tester,
  ) async {
    Widget app(bool harmony, {bool reduceMotion = false}) => MaterialApp(
      theme: harmony ? HarmonyTheme.apply(ThemeData()) : ThemeData(),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: const Center(child: M3ELoadingIndicator()),
      ),
    );
    await tester.pumpWidget(app(true));
    expect(find.byType(HarmonyLoadingIndicator), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pumpWidget(app(true, reduceMotion: true));
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(app(false));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(HarmonyLoadingIndicator), findsNothing);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Harmony switch supports taps, drag, keyboard and accessible state',
    (tester) async {
      bool value = false;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Center(
              child: HarmonySwitch(
                value: value,
                onChanged: (next) => setState(() => value = next),
              ),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(HarmonySwitch)), const Size(52, 48));
      await tester.tap(find.byType(HarmonySwitch));
      await tester.pumpAndSettle();
      expect(value, isTrue);
      await tester.drag(find.byType(HarmonySwitch), const Offset(-40, 0));
      await tester.pumpAndSettle();
      expect(value, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(value, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('settings panels fit narrow/wide windows and large text', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    for (final width in [320.0, 700.0, 1200.0]) {
      tester.view.physicalSize = Size(width, 1000);
      await tester.pumpWidget(
        MaterialApp(
          theme: HarmonyTheme.apply(ThemeData()),
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 1000),
              textScaler: const TextScaler.linear(1.5),
            ),
            child: Scaffold(
              body: HarmonySettingsList(
                itemCount: 8,
                itemBuilder: (context, index) => ListTile(
                  title: Text('设置选项 $index'),
                  subtitle: const Text('展开后继续保留悬浮导航，支持左右手握持和大字体显示'),
                  trailing: HarmonySwitch(value: true, onChanged: (_) {}),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(ListView)).width,
        lessThanOrEqualTo(840),
      );
      expect(tester.takeException(), isNull);
    }
  });
}
