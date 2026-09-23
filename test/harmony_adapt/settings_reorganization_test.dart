import 'package:PiliPlus/pages/setting/common_setting.dart';
import 'package:PiliPlus/models/common/setting_type.dart';
import 'package:PiliPlus/harmony_adapt/appearance.dart';
import 'package:PiliPlus/pages/setting/models/experimental_settings.dart';
import 'package:PiliPlus/pages/setting/models/extra_settings.dart';
import 'package:PiliPlus/pages/setting/models/style_settings.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/theme_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:os_type/os_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'helpers/memory_box.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    GStorage.setting = MemoryBox();
    debugDefaultTargetPlatformOverride = TargetPlatform.ohos;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('os_type'),
          (_) async => 'phone',
        );
    await OS.initHarmonyDeviceType();
    debugDefaultTargetPlatformOverride = null;
  });
  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.ohos;
    await GStorage.setting.put(SettingBoxKey.materialYouUI, true);
    Pref.captureAppearanceAtStartup();
    await GStorage.setting.put(SettingBoxKey.harmonyNativeColors, false);
    await GStorage.setting.put(SettingBoxKey.isPureBlackTheme, false);
    await GStorage.setting.put(SettingBoxKey.harmonyNavigation, 0);
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test(
    'Harmony defaults on; Material You changes only on next startup',
    () async {
      // Older disabled Harmony values must not reverse the new default.
      await GStorage.setting.delete(SettingBoxKey.materialYouUI);
      await GStorage.setting.put(SettingBoxKey.harmonyUI, false);
      expect(Pref.materialYouUI, isFalse);
      Pref.captureAppearanceAtStartup();
      expect(Pref.harmonyUI, isTrue);
      await GStorage.setting.put(SettingBoxKey.materialYouUI, true);
      expect(Pref.materialYouUI, isTrue);
      expect(Pref.harmonyUI, isTrue);
      Pref.captureAppearanceAtStartup();
      expect(Pref.harmonyUI, isFalse);
      await GStorage.setting.put(SettingBoxKey.materialYouUI, false);
      expect(Pref.harmonyUI, isFalse);
      Pref.captureAppearanceAtStartup();
      expect(Pref.harmonyUI, isTrue);
    },
  );

  test(
    'old orientation and transition values survive but no longer override Harmony policy',
    () async {
      await GStorage.setting.put(SettingBoxKey.horizontalScreen, false);
      await GStorage.setting.put(
        SettingBoxKey.pageTransition,
        Transition.fadeIn.index,
      );
      expect(Pref.horizontalScreen, isTrue);
      expect(Pref.legacyHorizontalScreen, isFalse);
      expect(Pref.pageTransition, Transition.native);
      expect(GStorage.setting.get(SettingBoxKey.horizontalScreen), isFalse);
      expect(
        GStorage.setting.get(SettingBoxKey.pageTransition),
        Transition.fadeIn.index,
      );
    },
  );

  test(
    'appearance drops obsolete choices and keeps native navigation and colors',
    () {
      final rows = styleSettings;
      final titles = rows.map((e) => e.title).toList();
      for (final title in [
        '横屏适配',
        '页面过渡动画',
        'MD3样式底栏',
        '改用侧边栏',
        '优化平板导航栏',
        '悬浮底栏',
        '应用主题',
      ]) {
        expect(titles, isNot(contains(title)));
      }
      expect(
        titles,
        containsAll(['鸿蒙底栏与侧栏', '颜色选择', '纯黑主题', '底栏项目与顺序', '默认启动页', '首页标签页']),
      );
      expect(rows.singleWhere((e) => e.title == '纯黑主题').disabledReason, isNull);
      expect(
        rows.singleWhere((e) => e.title == '鸿蒙底栏与侧栏').disabledReason!(),
        isNotNull,
      );
    },
  );

  test(
    'Harmony sections live in Other with conditional rows and no duplicated navigation',
    () async {
      expect(extraSettings.map((e) => e.title), contains('Material You 界面风格'));
      expect(extraSettings.map((e) => e.title), isNot(contains('沉浸光感')));
      await GStorage.setting.put(SettingBoxKey.materialYouUI, false);
      Pref.captureAppearanceAtStartup();
      expect(
        extraSettings.map((e) => e.title),
        containsAll(['沉浸光感', '采用鸿蒙原生配色', '智感握姿', '全屏跟随折叠形态']),
      );
      expect(extraSettings.map((e) => e.title), isNot(contains('鸿蒙底栏与侧栏')));
      expect(
        harmonyNavigationSettings.map((e) => e.title),
        contains('展开时也采用悬浮 Dock'),
      );
      await GStorage.setting.put(
        SettingBoxKey.harmonyNavigation,
        HarmonyNavigation.sideBar.index,
      );
      expect(
        harmonyNavigationSettings.map((e) => e.title),
        isNot(contains('展开时也采用悬浮 Dock')),
      );
    },
  );

  test(
    'custom accent stays available and preserves Harmony surfaces',
    () async {
      await GStorage.setting.put(SettingBoxKey.materialYouUI, false);
      Pref.captureAppearanceAtStartup();
      await GStorage.setting.put(SettingBoxKey.harmonyNativeColors, true);
      final entry = styleSettings.singleWhere((e) => e.title == '颜色选择');
      expect(entry.disabledReason, isNull);
      final scheme = ColorScheme.fromSeed(seedColor: Colors.blue);
      final before = ThemeUtils.getThemeData(
        colorScheme: scheme,
        isDynamic: false,
      );
      await HarmonyAppearance.selectCustomColors();
      expect(Pref.harmonyUI, isTrue);
      expect(Pref.harmonyNativeColors, isFalse);
      final after = ThemeUtils.getThemeData(
        colorScheme: scheme,
        isDynamic: false,
      );
      expect(after.colorScheme.primary, scheme.primary);
      expect(after.colorScheme.primary, isNot(before.colorScheme.primary));
      expect(after.scaffoldBackgroundColor, before.scaffoldBackgroundColor);
      expect(after.cardTheme, before.cardTheme);
      expect(after.colorScheme.surface, before.colorScheme.surface);
    },
  );

  test('pure black remains effective with Harmony native colors', () async {
    await GStorage.setting.put(SettingBoxKey.materialYouUI, false);
    Pref.captureAppearanceAtStartup();
    await GStorage.setting.put(SettingBoxKey.harmonyNativeColors, true);
    await GStorage.setting.put(SettingBoxKey.isPureBlackTheme, true);
    final theme = ThemeUtils.getThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.pink,
        brightness: Brightness.dark,
      ),
      isDynamic: false,
      isDark: true,
    );
    expect(theme.scaffoldBackgroundColor, Colors.black);
    expect(
      theme.pageTransitionsTheme.builders[TargetPlatform.ohos],
      isA<OpenRightwardsPageTransitionsBuilder>(),
    );
  });

  testWidgets(
    'appearance layout fits original-resolution fold profiles and large text',
    (tester) async {
      debugDefaultTargetPlatformOverride = null;
      Get.testMode = true;
      await GStorage.setting.put(SettingBoxKey.materialYouUI, false);
      Pref.captureAppearanceAtStartup();
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
          final theme = ThemeUtils.getThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.pink),
            isDynamic: false,
            isDark: dark,
          );
          await tester.pumpWidget(
            GetMaterialApp(
              theme: theme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.3)),
                child: child!,
              ),
              home: const CommonSetting(settingType: SettingType.styleSetting),
            ),
          );
          await tester.pumpAndSettle();
          for (var i = 0; i < 12; i++) {
            await tester.drag(
              find.byType(ListView).first,
              const Offset(0, -450),
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '$pixels dark=$dark scroll=$i',
            );
          }
          await tester.pumpWidget(const SizedBox());
          Get.reset();
        }
      }
    },
  );

  testWidgets(
    'Get native route uses OHOS transition on push and returns to the previous page',
    (tester) async {
      debugDefaultTargetPlatformOverride = null;
      Get.testMode = true;
      await tester.pumpWidget(
        GetMaterialApp(
          defaultTransition: Transition.native,
          theme: ThemeData(platform: TargetPlatform.ohos),
          home: const Scaffold(body: Text('previous')),
        ),
      );
      Get.to(() => const Scaffold(body: Text('next')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(
        find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_OpenRightwardsPageTransition',
        ),
        findsWidgets,
      );
      await tester.pumpAndSettle();
      expect(find.text('next'), findsOneWidget);
      Get.back();
      await tester.pumpAndSettle();
      expect(find.text('previous'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      Get.reset();
    },
  );
}
