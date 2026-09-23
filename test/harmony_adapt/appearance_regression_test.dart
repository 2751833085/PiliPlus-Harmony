import 'package:PiliPlus/pages/dynamics_create/view.dart';
import 'package:PiliPlus/common/widgets/pair.dart';
import 'package:PiliPlus/plugin/pl_player/widgets/app_bar_ani.dart';
import 'dart:async';
import 'dart:io';
import 'package:PiliPlus/harmony_adapt/appearance.dart';
import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:PiliPlus/harmony_adapt/widgets/harmony_settings_list.dart';
import 'package:PiliPlus/pages/setting/widgets/setting_access.dart';
import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart'
    as refresh;
import 'package:PiliPlus/utils/storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:material_ui/material_ui.dart' as ui;

void main() {
  late Directory temp;
  setUpAll(() async {
    temp = await Directory.systemTemp.createTemp('piliplus-ui-test-');
    Hive.init(temp.path);
    GStorage.setting = await Hive.openBox('setting');
  });
  tearDownAll(() async {
    await Hive.close();
    await temp.delete(recursive: true);
  });

  testWidgets(
    'blocked setting cannot change; reason explains and unlock restores interaction',
    (tester) async {
      bool blocked = true;
      bool value = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingAccess(
              title: 'MD3样式底栏',
              reason: () => blocked ? '因为开启了鸿蒙界面风格，无法选择' : null,
              child: StatefulBuilder(
                builder: (context, setState) => SwitchListTile(
                  title: const Text('MD3样式底栏'),
                  value: value,
                  onChanged: (next) => setState(() => value = next),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tapAt(tester.getCenter(find.byType(Switch)));
      await tester.pumpAndSettle();
      expect(value, isTrue);
      expect(find.text('因为开启了鸿蒙界面风格，无法选择'), findsOneWidget);
      await tester.tap(find.text('知道了'));
      await tester.pumpAndSettle();
      blocked = false;
      HarmonyAppearance.changed();
      await tester.pump();
      await tester.tapAt(tester.getCenter(find.byType(Switch)));
      await tester.pumpAndSettle();
      expect(value, isFalse);
    },
  );

  testWidgets('settings search is a single bounded control with large text', (
    tester,
  ) async {
    for (final scale in [1.0, 1.8]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: HarmonyTheme.apply(ThemeData()),
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: const Scaffold(
              body: SizedBox(width: 320, child: _SearchFixture()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final search = find.byType(HarmonySettingsSearch);
      expect(tester.getSize(search).width, 288);
      expect(tester.getSize(search).height, greaterThanOrEqualTo(64));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'glass menu keeps selection, disabled item and dismissal behavior',
    (tester) async {
      int? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: HarmonyTheme.apply(ThemeData(), immersive: true),
          home: Scaffold(
            body: Center(
              child: ui.PopupMenuButton<int>(
                onSelected: (value) => selected = value,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 1, child: Text('正常选项')),
                  PopupMenuItem(value: 2, enabled: false, child: Text('不可用选项')),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(ui.PopupMenuButton<int>));
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsOneWidget);
      await tester.tap(find.text('不可用选项'));
      await tester.pumpAndSettle();
      expect(selected, isNull);
      expect(find.text('正常选项'), findsOneWidget);
      await tester.tap(find.text('正常选项'));
      await tester.pumpAndSettle();
      expect(selected, 1);
      expect(find.text('正常选项'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'dynamic composer fits phone, expanded display, long topic and keyboard',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      for (final width in [320.0, 840.0]) {
        tester.view.physicalSize = Size(width, 800);
        await tester.pumpWidget(
          MaterialApp(
            theme: HarmonyTheme.apply(ThemeData()),
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 800),
                textScaler: const TextScaler.linear(1.5),
                viewInsets: const EdgeInsets.only(bottom: 240),
              ),
              child: Scaffold(
                body: CreateDynPanel(
                  topic: Pair(
                    first: 1,
                    second: '这是一个很长的话题名称，用于验证单屏、展开屏和大字体不会挤压按钮',
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('发布动态'), findsOneWidget);
        expect(find.text('发布'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets(
    'compact controls fade without moving and hidden controls cannot be tapped',
    (tester) async {
      final animation = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 200),
      );
      addTearDown(animation.dispose);
      int taps = 0;
      const controlKey = Key('fade-control');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppBarAni(
                controller: animation,
                isTop: true,
                isFullScreen: false,
                removeSafeArea: true,
                fadeOnly: true,
                child: TextButton(
                  key: controlKey,
                  onPressed: () => taps++,
                  child: const Text('控制'),
                ),
              ),
            ),
          ),
        ),
      );
      final start = tester.getTopLeft(find.byKey(controlKey));
      await tester.tapAt(tester.getCenter(find.byKey(controlKey)));
      expect(taps, 0);
      animation.forward();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getTopLeft(find.byKey(controlKey)), start);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(controlKey));
      expect(taps, 1);
      animation.reverse();
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getCenter(find.byKey(controlKey)));
      expect(taps, 1);
    },
  );

  testWidgets(
    'bottom refresh keeps content fixed throughout the request',
    (tester) async {
      final complete = Completer<void>();
      final refreshKey = GlobalKey<refresh.RefreshIndicatorState>();
      const itemKey = Key('content-top');
      await tester.pumpWidget(
        MaterialApp(
          theme: HarmonyTheme.apply(ThemeData()),
          home: Scaffold(
            body: refresh.RefreshIndicator(
              key: refreshKey,
              onRefresh: () => complete.future,
              child: ListView(
                children: const [
                  SizedBox(key: itemKey, height: 100, child: Text('列表内容')),
                ],
              ),
            ),
          ),
        ),
      );
      final top = tester.getTopLeft(find.byKey(itemKey)).dy;
      final future = refreshKey.currentState!.show();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final held = tester.getTopLeft(find.byKey(itemKey)).dy;
      expect(held, closeTo(top, .1));
      await tester.pump(const Duration(seconds: 2));
      expect(tester.getTopLeft(find.byKey(itemKey)).dy, held);
      complete.complete();
      await future;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.getTopLeft(find.byKey(itemKey)).dy, closeTo(held, .1));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      expect(tester.getTopLeft(find.byKey(itemKey)).dy, closeTo(top, .1));
      expect(tester.takeException(), isNull);
    },
  );
}

class _SearchFixture extends StatelessWidget {
  const _SearchFixture();
  @override
  Widget build(BuildContext context) => HarmonySettingsList(
    itemCount: 2,
    bareIndices: const {0},
    sectionBuilder: (_) => '外观',
    itemBuilder: (_, index) => index == 0
        ? HarmonySettingsSearch(onTap: () {})
        : const ListTile(title: Text('选项')),
  );
}
