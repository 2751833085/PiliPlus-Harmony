import 'dart:io';

import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:PiliPlus/harmony_adapt/widgets/harmony_quick_actions.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/nav_bar_config.dart';
import 'package:PiliPlus/models_new/fav/fav_folder/data.dart';
import 'package:PiliPlus/pages/main/controller.dart';
import 'package:PiliPlus/pages/mine/controller.dart';
import 'package:PiliPlus/pages/mine/view.dart';
import 'package:PiliPlus/pages/mine/widgets/recent_history.dart';
import 'package:PiliPlus/services/account_service.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers/memory_box.dart';

class _MineOnlyMainController extends GetxController implements MainController {
  @override
  final selectedIndex = 1.obs;
  @override
  final navigationBars = [NavigationBarType.home, NavigationBarType.mine];
  @override
  bool get hasHome => true;
  @override
  RxDouble? get barOffset => null;
  @override
  RxBool? get showBottomBar => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory temp;
  setUpAll(() async {
    temp = await Directory.systemTemp.createTemp('mine-section-layout-');
    Hive.init(temp.path);
    await Accounts.init();
    GStorage.userInfo = MemoryBox();
    GStorage.reply = null;
    GStorage.localCache = MemoryBox();
    GStorage.setting = MemoryBox();
    await GStorage.setting.put(SettingBoxKey.showMineHistory, true);
  });
  tearDownAll(() async {
    await Hive.close();
    await temp.delete(recursive: true);
  });

  testWidgets('only single-screen Mine sections lose their outer surfaces', (
    tester,
  ) async {
    Get
      ..put(AccountService())
      ..put<MainController>(_MineOnlyMainController());
    final mine = Get.put(MineController());
    mine.loadingState.value = Success(FavFolderData());
    tester.view.devicePixelRatio = 2.875;
    addTearDown(tester.view.reset);
    addTearDown(Get.reset);

    await tester.pumpWidget(
      GetMaterialApp(
        theme: HarmonyTheme.apply(ThemeData(), immersive: true),
        home: const Scaffold(body: MinePage()),
        getPages: [
          GetPage(
            name: '/download',
            page: () => const Scaffold(body: Text('打开离线缓存')),
          ),
        ],
      ),
    );
    for (final (pixels, boxed) in [
      (const Size(1008, 2232), false),
      (const Size(2232, 1008), false),
      (const Size(2048, 2232), true),
      (const Size(3184, 2232), true),
      (const Size(1008, 2232), false),
    ]) {
      tester.view.physicalSize = pixels;
      await tester.pumpAndSettle();
      for (final section in [
        find.text('点击登录'),
        find.byType(HarmonyQuickActions),
        find.byType(MineHistoryPreview),
        find.textContaining('我的收藏', findRichText: true),
        find.text('暂无稍后再看的视频'),
      ]) {
        await tester.scrollUntilVisible(
          section,
          100,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          find.ancestor(of: section, matching: find.byType(ImmersiveSurface)),
          boxed ? findsOneWidget : findsNothing,
          reason: '$pixels',
        );
      }
      expect(
        find.ancestor(
          of: find.byTooltip('设置'),
          matching: find.byType(ImmersiveInteraction),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
    final download = find.text('离线缓存');
    await tester.scrollUntilVisible(
      download,
      -100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(download);
    await tester.pumpAndSettle();
    expect(find.text('打开离线缓存'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    Get
      ..delete<MineController>()
      ..delete<MainController>();
  });
}
