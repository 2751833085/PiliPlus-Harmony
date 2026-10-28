import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/common/skeleton/video_card_h.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/video_card/video_card_h.dart';
import 'package:PiliPlus/common/widgets/video_card/video_card_h_layout.dart';
import 'package:PiliPlus/common/widgets/video_popup_menu.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/model_hot_video_item.dart';
import 'package:PiliPlus/pages/video/related/controller.dart';
import 'package:PiliPlus/pages/video/related/view.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:get/get.dart';
import 'helpers/memory_box.dart';

void main() {
  setUpAll(() {
    GStorage.setting = MemoryBox();
  });
  setUp(() {
    Get.testMode = true;
    Get.routing.args = {'bvid': 'BV-test'};
  });
  tearDown(Get.reset);
  testWidgets(
    'sidebar placeholders retain cover ratio and fit narrow and wide panes',
    (tester) async {
      for (final width in [260.0, 320.0, 440.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox(
                width: width,
                height: 116,
                child: const VideoCardHSkeleton(adaptiveCover: true),
              ),
            ),
          ),
        );
        final cover = tester.getSize(find.byType(AspectRatio));
        expect(cover.width / cover.height, closeTo(Style.aspectRatio, .001));
        expect(cover.width, lessThan(width / 2));
        expect(cover.height, lessThanOrEqualTo(106));
        await tester.pump(const Duration(milliseconds: 120));
        expect(tester.getSize(find.byType(AspectRatio)), cover);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'double-fold related cards keep cover size through loading and readable compact metadata',
    (tester) async {
      tester.view.devicePixelRatio = 2.875;
      tester.view.physicalSize = const Size(2048, 2232);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final controller = Get.put(
        RelatedController(autoQuery: false),
        tag: 'dual',
      );
      final items = List.generate(
        3,
        (index) => HotVideoItemModel.fromJson({
          'bvid': 'BV-test-$index',
          'title': '这是一个需要显示两行的相关视频标题 $index',
          'pubdate': 1731650000,
          'duration': 62,
          'owner': {'name': '视频作者'},
          'stat': {'view': 158000, 'danmaku': 893},
        }),
      );
      for (final scale in [1.0, 1.3, 1.8]) {
        controller.loadingState.value =
            LoadingState<List<HotVideoItemModel>?>.loading();
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: const Center(
                child: SizedBox(
                  width: 251,
                  height: 600,
                  child: CustomScrollView(
                    slivers: const [
                      RelatedVideoPanel(
                        heroTag: 'dual',
                        sidebar: true,
                        compactSidebar: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        final loadingCover = tester.getSize(find.byType(AspectRatio).first);
        expect(
          loadingCover.width / loadingCover.height,
          closeTo(Style.aspectRatio, .001),
        );
        expect(loadingCover.width, closeTo(113.5, .01));
        controller.loadingState.value = Success(items);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        expect(tester.getSize(find.byType(AspectRatio).first), loadingCover);
        expect(find.byType(VideoCardHSkeleton), findsNothing);
        final cards = find.byType(VideoCardH);
        final first = cards.first;
        final menu = find.descendant(
          of: first,
          matching: find.byType(VideoPopupMenu),
        );
        final play = find.descendant(of: first, matching: find.text('15.8万'));
        final danmaku = find.descendant(of: first, matching: find.text('893'));
        final metadata = find.descendant(
          of: first,
          matching: find.textContaining('视频作者'),
        );
        final title = find.descendant(
          of: first,
          matching: find.textContaining('相关视频标题'),
        );
        expect(tester.getSize(menu), const Size(40, 40));
        expect(tester.widget<Text>(play).style!.fontSize, 12);
        expect(tester.widget<Text>(danmaku).style!.fontSize, 12);
        expect(
          find.descendant(of: first, matching: find.byType(FittedBox)),
          findsNothing,
        );
        expect(
          tester.getTopLeft(metadata).dy - tester.getBottomLeft(title).dy,
          closeTo(4, .01),
        );
        expect(tester.getRect(play).overlaps(tester.getRect(menu)), isFalse);
        expect(tester.getRect(danmaku).overlaps(tester.getRect(menu)), isFalse);
        expect(
          tester.getTopLeft(play).dy,
          lessThan(tester.getTopLeft(danmaku).dy),
        );
        expect(
          tester.getBottomLeft(danmaku).dy,
          lessThanOrEqualTo(tester.getBottomLeft(first).dy),
        );
        final extent = VideoCardHLayout.compactRowExtent(
          titleFontSize: 14 * scale,
          metadataFontSize: 12 * scale,
        );
        expect(tester.getSize(first).height, closeTo(extent, .01));
        if (scale == 1) expect(extent, 104);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets(
    'existing sidebar cards retain 116dp rows and their original cover width',
    (tester) async {
      final controller = Get.put(
        RelatedController(autoQuery: false),
        tag: 'existing',
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: SizedBox(
              width: 251,
              height: 600,
              child: CustomScrollView(
                slivers: [
                  RelatedVideoPanel(heroTag: 'existing', sidebar: true),
                ],
              ),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(VideoCardHSkeleton).first).height, 116);
      expect(
        tester.getSize(find.byType(AspectRatio).first).width,
        closeTo(104.42, .01),
      );
      expect(controller.loadingState.value, isA<Loading>());
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
