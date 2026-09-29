import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:PiliPlus/pages/setting/models/model.dart';
import 'package:PiliPlus/pages/rcmd/controller.dart';
import 'package:PiliPlus/http/loading_state.dart';
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
    GStorage.video = MemoryBox();
    GStorage.localCache = MemoryBox();
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
    'initial recommendation failures show retry while refresh keeps existing data',
    () {
      final controller = RcmdController()..enableSaveLastData = true;
      expect(controller.handleError('offline'), isFalse);
      controller.loadingState.value = Success([Object()]);
      expect(controller.handleError('offline'), isTrue);
      controller.loadingState.value = Success([]);
      expect(controller.handleError('offline'), isFalse);
      controller.scrollController.dispose();
    },
  );

  test(
    'Harmony remains active regardless of obsolete Material You settings',
    () async {
      await GStorage.setting.delete(SettingBoxKey.customColor);
      expect(Pref.customColor, 1);
      await GStorage.setting.put(SettingBoxKey.customColor, 12);
      expect(Pref.customColor, 12);
      await GStorage.setting.delete(SettingBoxKey.customColor);
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
      expect(Pref.harmonyUI, isTrue);
      await GStorage.setting.put(SettingBoxKey.materialYouUI, false);
      expect(Pref.harmonyUI, isTrue);
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
      expect(titles, isNot(contains('Material You 界面风格')));
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
        containsAll(['颜色选择', '纯黑主题', '底栏项目与顺序', '默认启动页', '首页标签页']),
      );
      expect(rows.singleWhere((e) => e.title == '纯黑主题').disabledReason, isNull);
      expect(titles, isNot(contains('底栏样式')));
    },
  );

  test(
    'appearance owns Harmony style with conditional rows and no duplicate navigation',
    () async {
      expect(
        styleSettings.map((e) => e.title),
        isNot(contains('Material You 界面风格')),
      );
      expect(styleSettings.map((e) => e.title), contains('沉浸光感'));
      await GStorage.setting.put(SettingBoxKey.materialYouUI, false);
      Pref.captureAppearanceAtStartup();
      expect(
        styleSettings.map((e) => e.title),
        contains('沉浸光感'),
      );
      expect(extraSettings.map((e) => e.title), isNot(contains('底栏样式')));
      expect(
        harmonyNavigationSettings.map((e) => e.title),
        isNot(contains('展开时也采用悬浮 Dock')),
      );
      await GStorage.setting.put(
        SettingBoxKey.harmonyNavigation,
        2,
      );
      expect(Pref.harmonyNavigation, HarmonyNavigation.bottomBar);
      expect(HarmonyNavigation.values.length, 2);
      expect(
        harmonyNavigationSettings.map((e) => e.title),
        isNot(contains('展开时也采用悬浮 Dock')),
      );
    },
  );

  test(
    'related categories share settings while search deduplicates and values persist',
    () async {
      await GStorage.setting.put(SettingBoxKey.materialYouUI, false);
      Pref.captureAppearanceAtStartup();
      await GStorage.setting.put(SettingBoxKey.shortVideoMode, true);
      await GStorage.setting.put(SettingBoxKey.overseasMode, true);
      final catalog = {
        for (final type in SettingType.searchable) type: type.settings,
      };
      final rows = SettingType.searchSettings;
      expect(catalog[SettingType.videoSetting]!.first.effectiveTitle, '默认画质');
      expect(
        catalog[SettingType.playSetting]!.first.effectiveTitle,
        '自动播放',
      );
      expect(
        catalog[SettingType.styleSetting]!
            .firstWhere((row) => row.section == '主题与显示')
            .effectiveTitle,
        '颜色选择',
      );
      expect(SettingType.featuredSetting.settings.first.effectiveTitle, '空降助手');

      final titles = rows.map((row) => row.effectiveTitle).toList();
      expect(
        titles.toSet().length,
        titles.length,
        reason: 'No duplicate search entries',
      );
      final keys = <String>[];
      for (final row in rows) {
        if (row is SwitchModel) keys.add(row.setKey);
        if (row is SplitModel) keys.add(row.switchModel.setKey);
        expect(row.section, isNotNull, reason: row.effectiveTitle);
      }
      expect(keys.toSet().length, keys.length);
      expect(
        catalog[SettingType.styleSetting]!.map((e) => e.effectiveTitle),
        containsAll(['颜色选择', '沉浸光感', '在我的页面展示观看历史']),
      );
      expect(
        catalog[SettingType.playSetting]!.map((e) => e.effectiveTitle),
        containsAll(['全屏跟随折叠形态', '空降助手', '弹幕行高']),
      );
      expect(
        catalog[SettingType.videoSetting]!.map((e) => e.effectiveTitle),
        containsAll(['海外模式', 'CDN 设置', '音量均衡', '设置代理']),
      );
      expect(
        catalog[SettingType.recommendSetting]!.map((e) => e.effectiveTitle),
        containsAll(['记录搜索历史', '评论关键词过滤', '动态关键词过滤']),
      );
      expect(SettingType.recommendSetting.title, '个性化设置');
      expect(
        SettingType.privacySetting.settings.map((e) => e.effectiveTitle),
        containsAll([
          '黑名单管理',
          '记录搜索历史',
          '记录评论',
          '在我的页面展示观看历史',
          '禁用 SSL 证书验证',
          '设置代理',
        ]),
      );
      expect(
        SettingType.featuredSetting.settings.map((e) => e.effectiveTitle),
        containsAll(['空降助手', '海外模式', '启用AI总结', '沉浸光感']),
      );
      for (final type in [
        SettingType.playSetting,
        SettingType.videoSetting,
        SettingType.featuredSetting,
      ]) {
        expect(
          type.settings.map((row) => row.effectiveTitle),
          isNot(contains('连续视频预加载')),
        );
      }
      expect(
        extraSettings.map((e) => e.effectiveTitle),
        containsAll(['应用接续', '最大缓存大小', '检查更新']),
      );
      expect(
        extraSettings.map((e) => e.effectiveTitle),
        isNot(contains('启用短视频模式（实验性）')),
      );
      expect(titles, isNot(contains('智感握姿')));
      expect(titles, isNot(contains('启用短视频模式（实验性）')));
      expect(titles, isNot(contains('播放器音量')));
      expect(titles, isNot(contains('哔哩哔哩式播放器控制栏')));
      final overseas =
          rows.singleWhere((e) => e.title == '海外模式') as SwitchModel;
      expect(Pref.shortVideoMode, isFalse);
      expect(Pref.biliPlayerControls, isTrue);
      expect(Pref.harmonyHandedness, isFalse);
      expect(GStorage.setting.get(overseas.setKey), isTrue);
    },
  );

  testWidgets(
    'shared switches update in both menus without duplicate side effects',
    (tester) async {
      debugDefaultTargetPlatformOverride = null;
      await GStorage.setting.put(SettingBoxKey.showMineHistory, false);
      final appearance = SettingType.styleSetting.settings.singleWhere(
        (e) => e.title == '在我的页面展示观看历史',
      );
      final privacy = SettingType.privacySetting.settings.singleWhere(
        (e) => e.title == '在我的页面展示观看历史',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(children: [appearance.widget, privacy.widget]),
          ),
        ),
      );
      expect(
        tester.widgetList<Switch>(find.byType(Switch)).map((w) => w.value),
        [false, false],
      );
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(
        tester.widgetList<Switch>(find.byType(Switch)).map((w) => w.value),
        [true, true],
      );
      await tester.tap(find.byType(Switch).last);
      await tester.pumpAndSettle();
      expect(
        tester.widgetList<Switch>(find.byType(Switch)).map((w) => w.value),
        [false, false],
      );
      await tester.pumpWidget(const SizedBox());
      await GStorage.setting.put(SettingBoxKey.showMineHistory, true);
      expect(tester.takeException(), isNull);
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
      await GStorage.setting.put(SettingBoxKey.harmonyNativeColors, false);
      HarmonyAppearance.changed();
      expect(Pref.harmonyUI, isTrue);
      expect(styleSettings.map((e) => e.title), isNot(contains('采用鸿蒙原生配色')));
      final after = ThemeUtils.getThemeData(
        colorScheme: scheme,
        isDynamic: false,
      );
      expect(after.colorScheme.primary, scheme.primary);
      expect(after.colorScheme.primary, before.colorScheme.primary);
      expect(after.colorScheme.onSurface, const Color(0xFF191A1C));
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
      isA<HarmonyPageTransitionsBuilder>(),
    );
  });

  testWidgets(
    'all setting categories fit original-resolution fold profiles and large text',
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
        for (final type in [
          ...SettingType.searchable,
          SettingType.featuredSetting,
        ]) {
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
                home: CommonSetting(settingType: type),
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
                reason: '$type $pixels dark=$dark scroll=$i',
              );
            }
            await tester.pumpWidget(const SizedBox());
            Get.reset();
          }
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
          theme: ThemeUtils.getThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.pink),
            isDynamic: false,
          ).copyWith(platform: TargetPlatform.ohos),
          home: const Scaffold(body: Text('previous')),
        ),
      );
      Get.to(() => const Scaffold(body: Text('next')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(
        find.byWidgetPredicate(
          (w) => w is SlideTransition,
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
