import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/pages/episode_panel/layout.dart';
import 'package:PiliPlus/pages/episode_panel/view.dart';
import 'package:PiliPlus/pages/video/widgets/collapsible_playlist.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/controller.dart';
import 'package:PiliPlus/models/common/episode_panel_type.dart';
import 'package:PiliPlus/models_new/video/video_detail/page.dart';
import 'package:PiliPlus/models/user/info.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'helpers/memory_box.dart';

class _Intro implements UgcIntroController {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() {
    GStorage.setting = MemoryBox<dynamic>();
    GStorage.localCache = MemoryBox<dynamic>();
    GStorage.userInfo = MemoryBox<UserInfoData>();
  });
  for (final width in [350.0, 712.0, 1108.0]) {
    for (final dark in [false, true]) {
      testWidgets(
        'episode sheet is readable and reaches final row at $width dark=$dark',
        (tester) async {
          tester.view.physicalSize = Size(width, 776);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final entries = List.generate(
            20,
            (i) =>
                Part(cid: i + 1, part: '第${i + 1}集 一个足够长的视频标题用于验证文字不会被截断到不可阅读'),
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(
                brightness: dark ? Brightness.dark : Brightness.light,
              ),
              home: Scaffold(
                body: Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    width: 560,
                    height: 500,
                    child: EpisodePanel(
                      ugcIntroController: _Intro(),
                      heroTag: 'layout',
                      type: EpisodeType.part,
                      aid: 1,
                      bvid: 'BV1',
                      cid: 1,
                      cover: null,
                      enableSlide: false,
                      list: [entries],
                      onChangeEpisode: (_) async => true,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(BackdropFilter), findsOneWidget);
          final list = tester
              .state<ScrollableState>(find.byType(Scrollable).last)
              .position;
          list.jumpTo(list.maxScrollExtent);
          await tester.pumpAndSettle();
          final last = tester.getRect(find.text(entries.last.part!));
          expect(last.bottom, lessThanOrEqualTo(776));
          expect(last.top, greaterThan(276));
          // The final row ends close to the sheet edge, without a 100px empty footer.
          expect(776 - last.bottom, lessThan(90));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'embedded playlist opens in its own column and does not blur the feed',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topRight,
              child: SizedBox(
                width: 300,
                child: CollapsiblePlaylist(
                  builder: (_) => const EpisodePanelSurface(
                    overlay: false,
                    child: Text('episodes'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('episodes'), findsNothing);
      await tester.tap(find.text('播放列表'));
      await tester.pumpAndSettle();
      expect(find.text('episodes'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(
        tester.getSize(find.byType(EpisodePanelSurface)).height,
        inInclusiveRange(220, 360),
      );
      await tester.tap(find.text('播放列表'));
      await tester.pumpAndSettle();
      expect(find.text('episodes'), findsNothing);
    },
  );
  test('cover preserves 16:9 and leaves space for copy in narrow columns', () {
    for (final width in [260.0, 320.0, 528.0]) {
      expect(EpisodeLayout.coverWidth(width), lessThanOrEqualTo(width * .4));
    }
  });
}
