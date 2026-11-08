import 'package:PiliPlus/models_new/pgc/pgc_info_model/result.dart';
import 'package:PiliPlus/pages/video/controller.dart';
import 'package:PiliPlus/pages/video/introduction/pgc/controller.dart';
import 'package:PiliPlus/pages/video/introduction/pgc/view.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'helpers/memory_box.dart';

const _tag = 'pgc-scroll-fixture';

// The fixture initializes only cid and owns no player or route resources.
class _Video extends VideoDetailController {
  @override
  // ignore: must_call_super
  void onInit() => cid = 1.obs;

  @override
  void onClose() => cid.close();
}

class _Intro extends PgcIntroController {
  // Provide fixture data without the route arguments or network requests.
  @override
  // ignore: must_call_super
  void onInit() {
    isPgc = true;
    hasLater = false.obs;
    pgcItem = PgcInfoModel.fromJson({
      'type': 1,
      'title': '番剧详情测试',
      'cover': '',
      'evaluate': '简介内容',
      'new_ep': {'desc': '全 12 话'},
      'publish': {'pub_time_show': '2026'},
      'stat': {'views': 1, 'danmakus': 1, 'share': 1},
    });
  }
}

void main() {
  setUpAll(() {
    GStorage.setting = MemoryBox();
    GStorage.video = MemoryBox();
    GStorage.localCache = MemoryBox();
  });
  tearDown(Get.reset);

  Future<void> mountPane(
    WidgetTester tester,
    ScrollController scroll, {
    required double height,
  }) async {
    tester.view
      ..devicePixelRatio = 2.875
      ..physicalSize = const Size(3184, 2232);
    addTearDown(tester.view.reset);
    Get
      ..put<VideoDetailController>(_Video(), tag: _tag)
      ..put<PgcIntroController>(_Intro(), tag: _tag);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 680,
              height: height,
              child: CustomScrollView(
                controller: scroll,
                physics: pgcDetailScrollPhysics,
                slivers: [
                  PgcIntroPage(
                    heroTag: _tag,
                    showEpisodes: () {},
                    showIntroDetail: (_, _) {},
                    maxWidth: 680,
                    isLandscape: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('short PGC details stretch and return from the top edge', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await mountPane(tester, scroll, height: 400);
    expect(scroll.position.maxScrollExtent, 0);
    final drag = await tester.startGesture(
      tester.getCenter(find.text('番剧详情测试')),
    );
    await drag.moveBy(const Offset(0, 30));
    await tester.pump();
    await drag.moveBy(const Offset(0, 70));
    await tester.pump();
    expect(scroll.offset, lessThan(0));
    await drag.up();
    await tester.pumpAndSettle();
    expect(scroll.offset, closeTo(0, .01));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('scrolling PGC details reuses the recorded intro paint', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await mountPane(tester, scroll, height: 120);
    expect(scroll.position.maxScrollExtent, greaterThan(60));
    final intro = tester.widget<SliverToBoxAdapter>(
      find.descendant(
        of: find.byType(PgcIntroPage),
        matching: find.byType(SliverToBoxAdapter),
      ),
    );
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byWidget(intro.child!),
    )..debugResetMetrics();
    for (final offset in [12.0, 24.0, 36.0, 48.0]) {
      scroll.jumpTo(offset);
      await tester.pump();
    }
    expect(boundary.debugSymmetricPaintCount, 0);
    expect(boundary.debugAsymmetricPaintCount, greaterThan(0));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
