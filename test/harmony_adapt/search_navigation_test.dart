import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:PiliPlus/pages/search/view.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers/memory_box.dart';

class _ResultObserver extends NavigatorObserver {
  final pushed = <TransitionRoute<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is TransitionRoute<dynamic> &&
        (route.settings.name?.startsWith('/searchResult?') ?? false)) {
      pushed.add(route);
    }
  }
}

void main() {
  testWidgets(
    'rapid search submits open one route and restore focus after exit',
    (
      tester,
    ) async {
      GStorage.setting = MemoryBox();
      GStorage.historyWord = MemoryBox();
      await GStorage.setting.put(SettingBoxKey.searchSuggestion, false);
      await GStorage.setting.put(SettingBoxKey.enableHotKey, false);
      await GStorage.setting.put(SettingBoxKey.enableSearchRcmd, false);
      await GStorage.setting.put(SettingBoxKey.recordSearchHistory, false);
      addTearDown(Get.reset);

      final observer = _ResultObserver();
      await tester.pumpWidget(
        GetMaterialApp(
          theme: HarmonyTheme.apply(
            ThemeData(platform: TargetPlatform.ohos),
            immersive: true,
          ),
          defaultTransition: Transition.native,
          navigatorObservers: [observer],
          home: const Scaffold(body: Text('首页')),
          getPages: [
            GetPage(name: '/search', page: SearchPage.new),
            GetPage(
              name: '/searchResult',
              page: () => const Scaffold(body: Text('结果')),
            ),
          ],
        ),
      );
      Get.toNamed<void>('/search');
      await tester.pumpAndSettle();

      final field = find.byType(TextField);
      await tester.enterText(field, '第一条');
      final input = tester.widget<TextField>(field);
      final button = tester.widget<IconButton>(
        find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip == '搜索',
        ),
      );
      button.onPressed!();
      input.onSubmitted!('第一条');
      await tester.pumpAndSettle();
      expect(observer.pushed, hasLength(1));
      expect(input.focusNode!.hasFocus, isFalse);

      Get.back(result: true);
      await tester.pump();
      expect(observer.pushed.single.animation!.status, AnimationStatus.reverse);
      expect(input.focusNode!.hasFocus, isFalse);
      button.onPressed!();
      await tester.pumpAndSettle();
      expect(observer.pushed, hasLength(1));
      expect(input.focusNode!.hasFocus, isTrue);
      expect(Get.currentRoute, '/search');

      await tester.enterText(field, '第二条');
      await tester.tap(find.byTooltip('搜索'));
      await tester.pumpAndSettle();
      expect(observer.pushed, hasLength(2));
      expect(Get.parameters['keyword'], '第二条');

      Get.back();
      await tester.pumpAndSettle();
      Get.back();
      await tester.pumpAndSettle();
      expect(find.text('首页'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
