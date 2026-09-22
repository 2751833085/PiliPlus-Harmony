import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:PiliPlus/pages/episode_panel/view.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/controller.dart';
import 'package:PiliPlus/models/common/episode_panel_type.dart';
import 'package:PiliPlus/models/user/info.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'helpers/memory_box.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/pages/video/shorts/episodes.dart';
import 'package:PiliPlus/models_new/video/video_detail/data.dart';
import 'package:PiliPlus/models_new/video/video_detail/episode.dart';
import 'package:PiliPlus/models_new/video/video_detail/page.dart';
import 'package:PiliPlus/models_new/video/video_detail/section.dart';
import 'package:PiliPlus/models_new/video/video_detail/ugc_season.dart';

void main() {
  setUpAll(() {
    GStorage.setting = MemoryBox<dynamic>();
    GStorage.localCache = MemoryBox<dynamic>();
    GStorage.userInfo = MemoryBox<UserInfoData>();
  });
  for (final type in [EpisodeType.part, EpisodeType.season]) {
    testWidgets('actual $type panel opens and selects a playable identity', (
      tester,
    ) async {
      BaseEpisodeItem? selected;
      final nav = GlobalKey<NavigatorState>();
      final second = type == EpisodeType.part
          ? Part(cid: 21, page: 2, part: '第二集')
          : EpisodeItem(bvid: 'another', aid: 31, cid: 21, title: '第二集');
      final entries = <BaseEpisodeItem>[
        if (type == EpisodeType.part)
          Part(cid: 20, part: '第一集')
        else
          EpisodeItem(bvid: 'current', cid: 20, title: '第一集'),
        second,
      ];
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          builder: FlutterSmartDialog.init(),
          home: const Scaffold(body: Text('video')),
        ),
      );
      showModalBottomSheet<void>(
        context: nav.currentContext!,
        isScrollControlled: true,
        builder: (context) => SizedBox(
          height: 500,
          child: EpisodePanel(
            ugcIntroController: _Intro(),
            heroTag: 'fixture',
            type: type,
            aid: 30,
            bvid: 'current',
            cid: 20,
            cover: null,
            enableSlide: false,
            list: type == EpisodeType.part
                ? [entries]
                : [SectionItem(episodes: entries.cast<EpisodeItem>())],
            onClose: () => Navigator.of(context).pop(),
            onChangeEpisode: (episode) async {
              selected = prepareShortEpisode(episode, bvid: 'current', aid: 30);
              // A spy replaces decoder/network work, while the real panel tap,
              // current-item highlight and modal closure run unchanged.
              return false;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('第二集'));
      await tester.pumpAndSettle();
      expect(selected, same(second));
      expect(selected!.cid, 21);
      expect(selected!.bvid, type == EpisodeType.part ? 'current' : 'another');
      expect(find.byType(EpisodePanel), findsNothing);
      expect(find.text('video'), findsOneWidget);
      final dismiss = SmartDialog.dismiss(status: SmartStatus.allToast);
      // The toast helper awaits two timers even after removing its overlay.
      await tester.pump(SmartDialog.config.toast.animationTime);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      await dismiss;
      expect(tester.takeException(), isNull);
    });
  }

  test(
    'collection and parts coexist; empty sections cannot create a dead entry',
    () {
      final first = EpisodeItem(bvid: 'first', cid: 10);
      final second = EpisodeItem(bvid: 'second', cid: 20);
      final detail = VideoDetailData(
        ugcSeason: UgcSeason(
          sections: [
            SectionItem(),
            SectionItem(episodes: []),
            SectionItem(episodes: [first]),
            SectionItem(episodes: [second]),
          ],
        ),
        pages: [Part(cid: 20), Part(cid: 21)],
      );
      final sources = ShortVideoEpisodes(detail);
      expect(sources.sections.length, 2);
      expect(sources.parts.length, 2);
      expect(sources.sectionFor(20), 1);
      expect(sources.sectionFor(999), 0);
      expect(ShortVideoEpisodes(VideoDetailData()).isEmpty, true);
      expect(
        ShortVideoEpisodes(VideoDetailData(pages: [Part(cid: 1)])).isEmpty,
        true,
      );
    },
  );
  test(
    'parts retain their page metadata and inherit current identity; collection keeps its own identity',
    () {
      final part = Part(cid: 21, page: 2, part: '第二部分', firstFrame: 'frame');
      final chosen = prepareShortEpisode(
        part,
        bvid: 'current',
        aid: 30,
        cover: 'cover',
      );
      expect(chosen, same(part));
      expect(
        (chosen.bvid, chosen.aid, chosen.cid, chosen.title, chosen.cover),
        ('current', 30, 21, '第二部分', 'frame'),
      );
      final episode = EpisodeItem(bvid: 'other', aid: 31, cid: 99);
      expect(
        prepareShortEpisode(episode, bvid: 'current', aid: 30),
        same(episode),
      );
      expect((episode.bvid, episode.aid, episode.cid), ('other', 31, 99));
    },
  );
}

class _Intro implements UgcIntroController {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
