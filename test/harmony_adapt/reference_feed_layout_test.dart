import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/video_popup_menu.dart';
import 'package:PiliPlus/pages/live/widgets/live_item_app.dart';
import 'package:PiliPlus/models_new/live/live_feed_index/card_data_list_item.dart';
import 'package:PiliPlus/pages/pgc_index/widgets/pgc_card_v_pgc_index.dart';
import 'package:PiliPlus/models_new/pgc/pgc_index_result/list.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'dart:io';
import 'package:PiliPlus/common/widgets/video_card/video_card_v.dart';
import 'package:PiliPlus/models/home/rcmd/result.dart';
import 'package:PiliPlus/models_new/search/search_trending/list.dart';
import 'package:PiliPlus/pages/search/widgets/hot_keyword.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('feed-layout-');
    Hive.init(dir.path);
    GStorage.setting = await Hive.openBox('setting');
  });
  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });
  testWidgets('compact home cards fit actual fold widths and scaled titles', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2.875;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final width in [1008.0, 2048.0, 3184.0]) {
      tester.view.physicalSize = Size(width, 2232);
      for (final scale in [1.0, 1.3, 1.8]) {
        final columns = width == 1008
            ? 2
            : width == 2048
            ? 3
            : 4;
        final itemWidth = (width / 2.875 - (columns - 1) * 6 - 16) / columns;
        final expectedRatio = width == 1008 ? Style.aspectRatio : 4 / 3;
        await tester.pumpWidget(
          MaterialApp(
            theme: HarmonyTheme.apply(ThemeData.dark(), immersive: true),
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 2232) / 2.875,
                textScaler: TextScaler.linear(scale),
              ),
              child: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: itemWidth,
                    height: itemWidth / expectedRatio + 66 * scale,
                    child: VideoCardV(
                      homeLayout: true,
                      videoItem: RcmdVideoItemAppModel.fromJson({
                        'param': '170001',
                        'bvid': 'BV17x411w7KC',
                        'card_goto': 'av',
                        'title': '很长很长的视频标题：折叠屏展开和单屏的卡片比例与更多按钮',
                        'player_args': {
                          'aid': 170001,
                          'cid': 279786,
                          'duration': 600,
                        },
                        'cover_left_text_1': '104.9万',
                        'cover_left_text_2': '7543',
                        'args': {'up_name': '很长的作者名称', 'up_id': 1},
                      }),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '$width / $scale');
        final coverSize = tester.getSize(find.byType(NetworkImgLayer).first);
        expect(
          coverSize.width / coverSize.height,
          closeTo(expectedRatio, .001),
        );
        expect(find.byType(VideoPopupMenu), findsOneWidget);
        final card = tester.widget<Card>(find.byType(Card).first);
        expect(
          (card.shape! as RoundedRectangleBorder).borderRadius,
          Style.mdRadius,
        );
      }
    }
  });
  testWidgets(
    'live and programme cards fit physical fold sizes and text scales',
    (tester) async {
      tester.view.devicePixelRatio = 2.875;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final width in [1008.0, 2048.0, 3184.0]) {
        tester.view.physicalSize = Size(width, 2232);
        final columns = width == 1008
            ? 2
            : width == 2048
            ? 3
            : 4;
        final cardWidth = (width / 2.875 - 24 - (columns - 1) * 6) / columns;
        for (final scale in [1.0, 1.3, 1.8]) {
          for (final live in [true, false]) {
            final ratio = live ? 4 / 3 : .75;
            await tester.pumpWidget(
              MaterialApp(
                theme: HarmonyTheme.apply(ThemeData.dark(), immersive: true),
                home: MediaQuery(
                  data: MediaQueryData(
                    size: Size(width, 2232) / 2.875,
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: Scaffold(
                    body: Align(
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: cardWidth,
                        height: cardWidth / ratio + (live ? 66 : 50) * scale,
                        child: live
                            ? LiveCardVApp(
                                item: CardLiveItem(
                                  roomid: 1,
                                  title: '这是一个很长的直播标题用于验证卡片的双行布局',
                                  uname: '主播名称',
                                  areaName: '生活',
                                ),
                              )
                            : PgcCardVPgcIndex(
                                item: PgcIndexItem(
                                  seasonId: 1,
                                  title: '这是一个很长的番剧名称',
                                  indexShow: '更新至第十二集',
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pump();
            expect(
              tester.takeException(),
              isNull,
              reason: '$width / $scale / $live',
            );
            final image = tester.getSize(find.byType(NetworkImgLayer).first);
            expect(image.width / image.height, closeTo(ratio, .001));
          }
        }
      }
    },
  );
  testWidgets('search discovery remains two columns and empty data is safe', (
    tester,
  ) async {
    for (final count in [0, 1, 12]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverHotKeyword(
                  filled: true,
                  hotSearchList: List.generate(
                    count,
                    (i) => SearchTrendingItemModel(
                      keyword: '$i',
                      showName: '搜索发现 $i',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      if (count > 1)
        expect(
          tester.getTopLeft(find.text('搜索发现 0')).dy,
          tester.getTopLeft(find.text('搜索发现 1')).dy,
        );
    }
  });
}
