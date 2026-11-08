import 'dart:io';

import 'package:PiliPlus/common/widgets/flutter/list_tile.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:PiliPlus/harmony_adapt/widgets/harmony_quick_actions.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/nav_bar_config.dart';
import 'package:PiliPlus/models_new/fav/fav_folder/data.dart';
import 'package:PiliPlus/models_new/fav/fav_folder/list.dart';
import 'package:PiliPlus/models_new/history/data.dart';
import 'package:PiliPlus/models_new/history/history.dart';
import 'package:PiliPlus/models_new/history/list.dart';
import 'package:PiliPlus/models_new/later/list.dart';
import 'package:PiliPlus/pages/main/controller.dart';
import 'package:PiliPlus/pages/mine/controller.dart';
import 'package:PiliPlus/pages/mine/view.dart';
import 'package:PiliPlus/pages/mine/widgets/item.dart';
import 'package:PiliPlus/pages/mine/widgets/later_preview.dart';
import 'package:PiliPlus/pages/mine/widgets/recent_history.dart';
import 'package:PiliPlus/services/account_service.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';
import 'package:material_ui/material_ui.dart' hide ListTile;

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

  for (final brightness in Brightness.values) {
    for (final textScale in [1.0, 1.3]) {
      testWidgets(
        'single-screen Mine content edges and dock clearance at $brightness / $textScale',
        (tester) async {
          Get
            ..put(AccountService())
            ..put<MainController>(_MineOnlyMainController());
          final mine = Get.put(MineController());
          addTearDown(Get.reset);
          addTearDown(tester.view.reset);
          tester.view
            ..physicalSize = const Size(1008, 2232)
            ..devicePixelRatio = 2.875
            ..viewPadding = const FakeViewPadding(top: 72, bottom: 52)
            ..padding = const FakeViewPadding(top: 72, bottom: 52);

          const viewportWidth = 1008 / 2.875;
          const dock = ValueKey('mine-test-bottom-nav');
          const longTitle = '这个比较长的视频标题用于确认单屏大字号时仍能完整滚动看到卡片底部';
          const itemCount = 3;
          String historyTitle(int i) => '历史 $i $longTitle';
          String laterTitle(int i) => '稍后 $i $longTitle';
          mine.loadingState.value = Success(
            FavFolderData(
              count: itemCount,
              list: [
                for (var i = 0; i < itemCount; i++)
                  FavFolderInfo(
                    id: i,
                    title: '收藏 $i $longTitle',
                    mediaCount: 52,
                  ),
              ],
            ),
          );
          mine.recentHistory.configure(
            enabled: true,
            account: Object(),
            load: () async => Success(
              HistoryData(
                list: [
                  for (var i = 0; i < itemCount; i++)
                    HistoryItemModel(
                      title: historyTitle(i),
                      history: History(),
                      progress: 16,
                      duration: 100,
                    ),
                ],
              ),
            ),
          );
          mine.laterPreview.assignAll([
            for (var i = 0; i < itemCount; i++)
              LaterItemModel(title: laterTitle(i)),
          ]);
          await tester.pumpWidget(
            GetMaterialApp(
              theme: HarmonyTheme.apply(
                ThemeData(brightness: brightness),
                immersive: true,
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
              home: const Scaffold(
                extendBody: true,
                body: MinePage(),
                bottomNavigationBar: SizedBox(
                  key: dock,
                  height: 52 + 52 / 2.875,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final vertical = find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          );
          expect(vertical, findsOneWidget);
          final position = tester.state<ScrollableState>(vertical).position;

          final titleFinders = [
            find.text('我的'),
            find.byWidgetPredicate(
              (widget) => widget is Image && widget.semanticLabel == '默认头像',
            ),
            find.text('观看历史'),
            find.textContaining('我的收藏', findRichText: true),
            find.descendant(
              of: find.byType(ListTile),
              matching: find.text('稍后再看'),
            ),
          ];
          for (final target in titleFinders) {
            await tester.scrollUntilVisible(target, 150, scrollable: vertical);
            expect(
              tester.getTopLeft(target).dx,
              closeTo(16, .5),
              reason: target.description,
            );
          }

          final history = find.byType(MineHistoryPreview);
          final later = find.byType(MineLaterPreviewList);
          Finder historyCard(int index) => find.descendant(
            of: history,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics &&
                  widget.properties.label == '继续观看：${historyTitle(index)}',
            ),
          );
          Finder favoriteCard(int index) => find.byWidgetPredicate(
            (widget) => widget is FavFolderItem && widget.item.id == index,
          );
          Finder laterTitleFinder(int index) => find.descendant(
            of: later,
            matching: find.text(laterTitle(index)),
          );
          Finder laterCard(int index) => find
              .ancestor(
                of: laterTitleFinder(index),
                matching: find.byType(InkWell),
              )
              .first;
          Finder cover(Finder card) =>
              find.descendant(of: card, matching: find.byType(NetworkImgLayer));

          for (final (first, last) in [
            (historyCard(0), historyCard(itemCount - 1)),
            (favoriteCard(0), favoriteCard(itemCount - 1)),
            (laterCard(0), laterCard(itemCount - 1)),
          ]) {
            position.jumpTo(0);
            await tester.pumpAndSettle();
            await tester.scrollUntilVisible(first, 160, scrollable: vertical);
            expect(
              tester.getTopLeft(cover(first)).dx,
              closeTo(16, .5),
              reason: first.description,
            );
            final horizontal = Scrollable.of(
              tester.element(first),
              axis: Axis.horizontal,
            ).position;
            expect(horizontal.maxScrollExtent, greaterThan(0));
            horizontal.jumpTo(horizontal.maxScrollExtent);
            await tester.pumpAndSettle();
            expect(
              viewportWidth - tester.getTopRight(cover(last)).dx,
              closeTo(16, .5),
              reason: last.description,
            );
          }

          expect(position.maxScrollExtent, greaterThan(0));
          position.jumpTo(position.maxScrollExtent);
          await tester.pumpAndSettle();
          final dockTop = tester.getTopLeft(find.byKey(dock)).dy;
          expect(
            tester.getBottomLeft(later).dy,
            lessThanOrEqualTo(dockTop - 20),
          );
          expect(
            tester.getBottomLeft(laterTitleFinder(itemCount - 1)).dy,
            lessThan(dockTop),
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          Get
            ..delete<MineController>()
            ..delete<MainController>();
        },
      );
    }
  }
}
