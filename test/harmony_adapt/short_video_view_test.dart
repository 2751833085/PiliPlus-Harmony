import 'package:PiliPlus/pages/video/shorts/panel_theme.dart';
import 'package:PiliPlus/models_new/video/video_detail/page.dart';
import 'dart:convert';
import 'package:PiliPlus/pages/video/shorts/metrics.dart';
import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:PiliPlus/models_new/video/video_tag/data.dart';
import 'package:PiliPlus/models_new/video/video_detail/stat.dart';
import 'package:PiliPlus/pages/video/reply/widgets/panel_header.dart';
import 'package:PiliPlus/common/widgets/progress_bar/audio_video_progress_bar.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/models_new/member_card_info/data.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:PiliPlus/models/model_owner.dart';
import 'package:PiliPlus/models_new/relation/data.dart';
import 'dart:async';
import 'dart:io';
import 'package:PiliPlus/pages/video/shorts/pager.dart';
import 'package:PiliPlus/pages/video/shorts/session.dart';
import 'package:PiliPlus/pages/video/shorts/controls.dart';
import 'package:PiliPlus/pages/video/shorts/chrome.dart';
import 'package:PiliPlus/pages/video/shorts/view.dart';
import 'package:PiliPlus/pages/video/controller.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/controller.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/models/play_status.dart';
import 'package:PiliPlus/models_new/video/video_detail/data.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';

void main() {
  late Directory temp;
  setUpAll(() async {
    temp = await Directory.systemTemp.createTemp('piliplus-shorts-test-');
    Hive.init(temp.path);
    GStorage.setting = await Hive.openBox('setting');
    const fontPath = String.fromEnvironment('SHORTS_PREVIEW_FONT');
    if (fontPath.isNotEmpty) {
      final font = FontLoader('shorts-preview')
        ..addFont(
          File(fontPath).readAsBytes().then((b) => ByteData.sublistView(b)),
        );
      await font.load();
      const cjkPath = String.fromEnvironment('SHORTS_PREVIEW_CJK_FONT');
      if (cjkPath.isNotEmpty) {
        final cjk = FontLoader('shorts-preview-cjk')
          ..addFont(
            File(cjkPath).readAsBytes().then((b) => ByteData.sublistView(b)),
          );
        await cjk.load();
      }
      await (FontLoader(
        'custom_icon',
      )..addFont(rootBundle.load('assets/fonts/custom_icon.ttf'))).load();
      const iconPath = String.fromEnvironment('SHORTS_PREVIEW_ICONS');
      if (iconPath.isNotEmpty) {
        await (FontLoader('MaterialIcons')..addFont(
              File(iconPath).readAsBytes().then((b) => ByteData.sublistView(b)),
            ))
            .load();
      }
    }
  });
  tearDownAll(() async {
    await Hive.close();
    await temp.delete(recursive: true);
  });
  testWidgets(
    'buffer prefetch completion leaves the playing surface unchanged while new previews update',
    (tester) async {
      final session = ShortVideoSession(
        initial: const ShortVideoEntry(bvid: 'a'),
        loadRelated: (_) async => const [ShortVideoEntry(bvid: 'b')],
        play: (_) async => true,
      );
      final player = _FakePlayer();
      final video = _FakeVideo(player);
      var surfaceBuilds = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ShortVideoFeed(
            session: session,
            video: video,
            intro: _FakeIntro(),
            playerBuilder: (_, __) {
              surfaceBuilds++;
              return const ColoredBox(color: Colors.black);
            },
            onDetails: () {},
            onComments: () {},
            onEpisodes: () {},
            onMore: () {},
            fullscreen: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final buildsBeforeBuffering = surfaceBuilds;
      final requestsBeforeBuffering = video.warmRequests;
      final warm = Completer<void>();
      video.pendingWarm = warm.future;
      player.buffered.value = 90;
      await tester.pump(const Duration(milliseconds: 100));
      expect(video.warmRequests, greaterThan(requestsBeforeBuffering));
      warm.complete();
      await tester.pumpAndSettle();
      expect(
        surfaceBuilds,
        buildsBeforeBuffering,
        reason: 'Speculative bytes must not rebuild the entire playing page.',
      );
      video.shortPreviewRevision.value++;
      await tester.pumpAndSettle();
      expect(
        surfaceBuilds,
        greaterThan(buildsBeforeBuffering),
        reason: 'New neighbour preview images must still reach the pager.',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
  testWidgets(
    'vertical swipes retain exactly one live player and can return to previous video',
    (tester) async {
      final playerKey = GlobalKey();
      final changes = <String>[];
      final session = ShortVideoSession(
        initial: const ShortVideoEntry(bvid: 'a'),
        loadRelated: (_) async => const [
          ShortVideoEntry(bvid: 'b'),
          ShortVideoEntry(bvid: 'c'),
        ],
        play: (entry) async {
          changes.add(entry.bvid);
          return true;
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShortVideoPager(
              session: session,
              builder: (context, index, active) => active
                  ? _PlayerFixture(key: playerKey)
                  : const ColoredBox(color: Colors.black),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final initial = playerKey.currentState;
      await tester.drag(find.byType(PageView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(session.index, 1);
      expect(changes, ['b']);
      expect(find.byType(_PlayerFixture), findsOneWidget);
      expect(playerKey.currentState, same(initial));
      await tester.drag(find.byType(PageView), const Offset(0, 500));
      await tester.pumpAndSettle();
      expect(session.index, 0);
      expect(changes, ['b', 'a']);
      expect(playerKey.currentState, same(initial));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
  testWidgets(
    'dismissing the middle video keeps the player and page aligned, then swipes normally',
    (tester) async {
      final key = GlobalKey();
      final session = ShortVideoSession(
        initial: const ShortVideoEntry(bvid: 'a'),
        loadRelated: (_) async => const [
          ShortVideoEntry(bvid: 'b'),
          ShortVideoEntry(bvid: 'c'),
          ShortVideoEntry(bvid: 'd'),
        ],
        play: (_) async => true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShortVideoPager(
              session: session,
              builder: (_, index, active) => active
                  ? _PlayerFixture(key: key)
                  : Text(session.entries[index].bvid),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final state = key.currentState;
      await tester.drag(find.byType(PageView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(session.current.bvid, 'b');
      expect(await session.dismissCurrent(), isTrue);
      await tester.pumpAndSettle();
      expect(session.current.bvid, 'c');
      expect(session.index, 1);
      expect(key.currentState, same(state));
      expect(
        tester.getCenter(find.byType(_PlayerFixture)),
        const Offset(400, 300),
      );
      await tester.drag(find.byType(PageView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(session.current.bvid, 'd');
      await tester.drag(find.byType(PageView), const Offset(0, 500));
      await tester.pumpAndSettle();
      expect(session.current.bvid, 'c');
      expect(key.currentState, same(state));
      expect(find.byType(_PlayerFixture, skipOffstage: false), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
  testWidgets(
    'crossing halfway then dragging back does not open another video',
    (tester) async {
      var plays = 0;
      final key = GlobalKey();
      final session = ShortVideoSession(
        initial: const ShortVideoEntry(bvid: 'a'),
        loadRelated: (_) async => const [ShortVideoEntry(bvid: 'b')],
        play: (_) async {
          plays++;
          return true;
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShortVideoPager(
              session: session,
              builder: (_, index, active) => active
                  ? _PlayerFixture(key: key)
                  : const ColoredBox(color: Colors.black),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final state = key.currentState;
      final gesture = await tester.startGesture(const Offset(400, 520));
      await gesture.moveBy(const Offset(0, -410));
      await tester.pump(const Duration(milliseconds: 40));
      final pages = tester.widget<PageView>(find.byType(PageView)).controller!;
      expect(pages.page, greaterThan(.5));
      expect(plays, 0);
      expect(session.switching, isFalse);
      expect(key.currentState, same(state));
      await gesture.moveBy(const Offset(0, 360));
      await tester.pump(const Duration(milliseconds: 400));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(pages.page, 0);
      expect(plays, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );

  testWidgets(
    'source opening starts after snap and slow opening never blocks subsequent swipes',
    (tester) async {
      final key = GlobalKey();
      final first = Completer<bool>();
      final second = Completer<bool>();
      final plays = <String>[];
      final session = ShortVideoSession(
        initial: const ShortVideoEntry(bvid: 'a'),
        loadRelated: (_) async => const [
          ShortVideoEntry(bvid: 'b'),
          ShortVideoEntry(bvid: 'c'),
          ShortVideoEntry(bvid: 'd'),
          ShortVideoEntry(bvid: 'e'),
        ],
        play: (entry) {
          plays.add(entry.bvid);
          return entry.bvid == 'b' ? first.future : second.future;
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShortVideoPager(
              session: session,
              builder: (_, index, active) => active
                  ? _PlayerFixture(key: key)
                  : const ColoredBox(color: Colors.black),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final state = key.currentState;
      final gesture = await tester.startGesture(const Offset(400, 520));
      await gesture.moveBy(const Offset(0, -410));
      await tester.pump();
      final pages = tester.widget<PageView>(find.byType(PageView)).controller!;
      expect(plays, isEmpty);
      await gesture.up();
      var last = pages.page!;
      for (var i = 0; i < 80 && pages.position.isScrollingNotifier.value; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        final page = pages.page!;
        expect(page, greaterThanOrEqualTo(last - .0001));
        if (page < .999) expect(plays, isEmpty);
        last = page;
      }
      await tester.pump();
      expect(pages.page, 1);
      expect(plays, ['b']);
      expect(session.switching, isTrue);
      await tester.drag(find.byType(PageView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(pages.page, 2);
      await tester.drag(find.byType(PageView), const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(PageView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(pages.page, 4);
      expect(plays, [
        'b',
      ]); // One native open at a time; latest settled page wins.
      first.complete(true);
      await tester.pumpAndSettle();
      expect(pages.page, 4); // Never jump back to the intermediate page.
      expect(plays, ['b', 'e']);
      second.complete(true);
      await tester.pumpAndSettle();
      expect(session.index, 4);
      expect(key.currentState, same(state));
      expect(find.byType(_PlayerFixture), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );

  testWidgets(
    'slow stream loading retains the current player until the new source is ready',
    (tester) async {
      final key = GlobalKey();
      final gate = Completer<bool>();
      final session = ShortVideoSession(
        initial: const ShortVideoEntry(bvid: 'a'),
        loadRelated: (_) async => const [ShortVideoEntry(bvid: 'b')],
        play: (_) => gate.future,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShortVideoPager(
              session: session,
              builder: (_, index, active) => active
                  ? _PlayerFixture(key: key)
                  : const ColoredBox(color: Colors.black),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final state = key.currentState;
      await tester.drag(find.byType(PageView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(session.switching, isTrue);
      expect(key.currentState, same(state));
      gate.complete(true);
      await tester.pumpAndSettle();
      expect(session.index, 1);
      expect(key.currentState, same(state));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
  testWidgets(
    'failed switch returns to current player and account interaction blocks swiping',
    (tester) async {
      final session = ShortVideoSession(
        initial: const ShortVideoEntry(bvid: 'a'),
        loadRelated: (_) async => const [ShortVideoEntry(bvid: 'b')],
        play: (_) async => false,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShortVideoPager(
              session: session,
              builder: (_, index, active) =>
                  Center(child: Text('$index:$active')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(PageView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(session.index, 0);
      expect(
        tester.widget<PageView>(find.byType(PageView)).controller!.page,
        0,
      );
      final operation = Completer<void>();
      final interaction = session.interact(() => operation.future);
      await tester.pump();
      await tester.drag(find.byType(PageView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(
        tester.widget<PageView>(find.byType(PageView)).controller!.page,
        0,
      );
      operation.complete();
      await interaction;
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
  testWidgets(
    'actual feed fits phone and fold; paused, seeking, comments and fullscreen retain the player',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final nativeProfiles =
          Directory('test/harmony_adapt/fixtures/mate_xts_display')
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('.json'))
              .map(
                (file) =>
                    jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
              )
              .toList();
      // Official panel pixels are known even before a physical form is sampled.
      // These density sweeps are explicitly reference cases, NOT device measurements.
      // https://consumer.huawei.com/cn/phones/mate-xts-ultimate-design/specs/
      for (final width in [1008, 2048]) {
        for (final density in [2.5, 2.875, 3.25]) {
          nativeProfiles.add({
            'physical_size_px': [width, 2232],
            'device_pixel_ratio': density,
            'form':
                'reference-${width == 1008 ? "single" : "double"}-dpr$density',
          });
        }
      }
      final scenarios = [
        (
          size: Size(392, 2560 / 3),
          ratio: 3 / 4,
          label: '3x4',
          scale: 1.0,
          dpr: 1.0,
          uiScale: 1.0,
          form: 'generic',
        ),
        (
          size: Size(840, 800),
          ratio: 9 / 16,
          label: '9x16',
          scale: 1.0,
          dpr: 1.0,
          uiScale: 1.0,
          form: 'generic',
        ),
        (
          size: Size(390, 844),
          ratio: 9 / 16,
          label: '9x16',
          scale: 1.3,
          dpr: 1.0,
          uiScale: 1.0,
          form: 'generic',
        ),
        (
          size: Size(390, 844),
          ratio: 9 / 16,
          label: '9x16',
          scale: 2.0,
          dpr: 1.0,
          uiScale: 1.0,
          form: 'generic',
        ),
        (
          size: Size(390, 844),
          ratio: 9 / 16,
          label: '9x16',
          scale: 1.0,
          dpr: 1.0,
          uiScale: 1.0,
          form: 'generic',
        ),
        (
          size: Size(390, 844),
          ratio: 16 / 9,
          label: '16x9',
          scale: 1.0,
          dpr: 1.0,
          uiScale: 1.0,
          form: 'generic',
        ),
        (
          size: Size(320, 640),
          ratio: 9 / 16,
          label: '9x16',
          scale: 1.8,
          dpr: 1.0,
          uiScale: 1.0,
          form: 'generic',
        ),
        (
          size: Size(840, 800),
          ratio: 9 / 16,
          label: '9x16',
          scale: 1.8,
          dpr: 1.0,
          uiScale: 1.0,
          form: 'generic',
        ),
        (
          size: Size(600, 320),
          ratio: 9 / 16,
          label: '9x16',
          scale: 1.8,
          dpr: 1.0,
          uiScale: 1.0,
          form: 'generic',
        ),
        for (final profile in nativeProfiles)
          for (final source in const [
            (ratio: 9 / 16, label: '9x16'),
            (ratio: 3 / 4, label: '3x4'),
            (ratio: 16 / 9, label: '16x9'),
          ])
            for (final scaling in const [
              (text: 1.0, ui: 1.0),
              (text: 1.3, ui: 1.0),
              (text: 1.0, ui: 1.15),
            ])
              (
                size: Size(
                  (profile['physical_size_px'][0] as num).toDouble(),
                  (profile['physical_size_px'][1] as num).toDouble(),
                ),
                ratio: source.ratio,
                label: source.label,
                scale: scaling.text,
                dpr: (profile['device_pixel_ratio'] as num).toDouble(),
                uiScale: scaling.ui,
                form: profile['form'] as String,
              ),
      ];
      for (final scenario in scenarios) {
        final effectiveDpr = scenario.dpr * scenario.uiScale;
        final size = scenario.size / effectiveDpr;
        final previewSuffix = scenario.form == 'generic'
            ? '${size.width.toInt()}-${scenario.label}-${scenario.scale}'
            : 'native-${scenario.form}-${scenario.label}-text${scenario.scale}-ui${scenario.uiScale}';
        final metrics = ShortVideoMetrics(TextScaler.linear(scenario.scale));
        const insets = EdgeInsets.only(top: 32, bottom: 24);
        tester.view.devicePixelRatio = effectiveDpr;
        tester.view.physicalSize = scenario.size;
        final session = ShortVideoSession(
          initial: const ShortVideoEntry(
            bvid: 'a',
            cover: '',
            title: '很长的视频标题：从单屏展开到三屏时依然可以查看所有操作',
          ),
          loadRelated: (_) async => const [
            ShortVideoEntry(bvid: 'next', cover: ''),
          ],
          play: (_) async => true,
        );
        final player = _FakePlayer();
        final video = _FakeVideo(player);
        final intro = _FakeIntro();
        final playerKey = GlobalKey();
        final captureKey = GlobalKey();
        var commentsOpen = false;
        var danmakuSettings = 0;
        var episodeOpens = 0;
        final searchedTerms = <String>[];
        Widget build(bool fullscreen) => MaterialApp(
          theme: HarmonyTheme.apply(
            ThemeData(
              fontFamily:
                  const String.fromEnvironment('SHORTS_PREVIEW_FONT').isEmpty
                  ? null
                  : 'shorts-preview',
              fontFamilyFallback: const ['shorts-preview-cjk'],
            ),
          ),
          home: MediaQuery(
            data: MediaQueryData.fromView(tester.view).copyWith(
              textScaler: TextScaler.linear(scenario.scale),
              padding: insets,
              viewPadding: insets,
            ),
            child: RepaintBoundary(
              key: captureKey,
              child: ShortVideoFeed(
                commentsPanel: commentsOpen
                    ? Theme(
                        data: shortVideoPanelTheme(
                          ThemeData(
                            brightness: Brightness.dark,
                            fontFamily: 'shorts-preview',
                            fontFamilyFallback: const ['shorts-preview-cjk'],
                          ),
                        ),
                        child: Material(
                          color: shortVideoPanelTheme(
                            ThemeData.dark(),
                          ).colorScheme.surface,
                          child: Column(
                            children: [
                              ReplyPanelHeader(
                                title: '热门评论',
                                sortLabel: '最热',
                                onSort: () {},
                                onClose: () {},
                              ),
                              const Expanded(
                                child: Center(
                                  child: Text(
                                    '评论内容（布局测试）',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ),
                              ),
                              ShortReplyComposer(onReply: () {}),
                            ],
                          ),
                        ),
                      )
                    : null,
                session: session,
                video: video,
                intro: intro,
                playerBuilder: (_, __) => _PlayerFixture(
                  key: playerKey,
                  aspectRatio: scenario.ratio,
                  ratioLabel: scenario.label,
                ),
                onDetails: () {},
                onComments: () {},
                onEpisodes: () => episodeOpens++,
                onMore: () {},
                onDanmakuSettings: () => danmakuSettings++,
                onSearch: searchedTerms.add,
                fullscreen: fullscreen,
              ),
            ),
          ),
        );
        await tester.pumpWidget(build(false));
        await tester.pumpAndSettle();
        expect(find.byTooltip('普通详情'), findsOneWidget);
        expect(find.byType(ShortVideoControls), findsOneWidget);
        expect(tester.takeException(), isNull);
        for (final label in ['点赞', '评论', '投币', '收藏', '分享']) {
          expect(find.text(label), findsNothing);
        }
        expect(find.text('133'), findsOneWidget);
        final input = find.byKey(const ValueKey('short-danmaku-input'));
        final dmToggle = find.byTooltip('关闭弹幕');
        final dmSettings = find.byTooltip('弹幕设置');
        expect(tester.getSize(input).width, lessThanOrEqualTo(200));
        final inputText = find.descendant(
          of: input,
          matching: find.text('发弹幕'),
        );
        if (inputText.evaluate().isNotEmpty) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: inputText, matching: find.byType(RichText)),
          );
          expect(paragraph.didExceedMaxLines, false);
        } else {
          expect(
            find.descendant(
              of: input,
              matching: find.byIcon(Icons.edit_outlined),
            ),
            findsOneWidget,
          );
        }
        expect(
          tester.getRect(input).right,
          lessThan(tester.getRect(dmToggle).left),
        );
        expect(
          tester.getRect(dmToggle).right,
          lessThanOrEqualTo(tester.getRect(dmSettings).left),
        );
        await tester.tap(input);
        await tester.pumpAndSettle();
        expect(video.sendPanelOpens, 1);
        await tester.tap(dmSettings);
        await tester.pumpAndSettle();
        expect(danmakuSettings, 1);
        await tester.tap(dmToggle);
        await tester.pumpAndSettle();
        expect(player.enableShowDanmaku.value, isFalse);
        await tester.tap(find.byTooltip('开启弹幕'));
        await tester.pumpAndSettle();
        expect(player.enableShowDanmaku.value, isTrue);
        final search = find.byKey(const ValueKey('short-related-search'));
        expect(find.text('折叠屏体验'), findsOneWidget);
        // Very short windows scroll their information area; the search link
        // remains reachable without moving the live player.
        if (!search.hitTestable().evaluate().isNotEmpty) {
          await tester.ensureVisible(search);
          await tester.pumpAndSettle();
        }
        await tester.tap(search);
        await tester.pumpAndSettle();
        expect(searchedTerms, ['折叠屏体验']);
        final episodes = find.byKey(const ValueKey('short-episodes'));
        expect(tester.getRect(episodes).top, tester.getRect(search).top);
        expect(tester.getRect(episodes).height, tester.getRect(search).height);
        expect(
          tester.getRect(episodes).left,
          greaterThan(tester.getRect(search).right),
        );
        await tester.tap(episodes);
        await tester.pumpAndSettle();
        expect(episodeOpens, 1);
        final infoScroll = find
            .ancestor(of: search, matching: find.byType(SingleChildScrollView))
            .first;
        final scrollState = tester.state<ScrollableState>(
          find
              .descendant(of: infoScroll, matching: find.byType(Scrollable))
              .first,
        );
        scrollState.position.jumpTo(0);
        await tester.pumpAndSettle();
        final author = find.byKey(const ValueKey('short-author-info'));
        final follow = find.byKey(const ValueKey('short-follow'));
        final avatar = find.byKey(const ValueKey('short-author-avatar'));
        final authorRect = tester.getRect(author);
        final followRect = tester.getRect(follow);
        expect(followRect.left - authorRect.right, closeTo(8, .1));
        expect(followRect.center.dy, closeTo(authorRect.center.dy, .1));
        expect(tester.getSize(avatar), Size.square(metrics.avatar));
        final videoFrame = find.byKey(const ValueKey('fixture-video-frame'));
        final frameRect = tester.getRect(videoFrame);
        expect(
          frameRect.width / frameRect.height,
          closeTo(scenario.ratio, .001),
        );
        expect(frameRect.top, greaterThanOrEqualTo(insets.top));
        expect(
          frameRect.bottom,
          lessThanOrEqualTo(size.height - insets.bottom - metrics.footerHeight),
        );
        // Missing counts keep the icon and row geometry, without fake zeros or names.
        final likeRect = tester.getRect(find.byIcon(Icons.thumb_up_rounded));
        final originalStats = intro.videoDetail.value.stat;
        intro.videoDetail.value.stat = null;
        intro.videoDetail.refresh();
        await tester.pumpAndSettle();
        for (final label in ['点赞', '评论', '投币', '收藏', '分享']) {
          expect(find.text(label), findsNothing);
        }
        expect(find.text('133'), findsNothing);
        expect(tester.getRect(find.byIcon(Icons.thumb_up_rounded)), likeRect);
        intro.videoDetail.value.stat = originalStats;
        intro.videoDetail.refresh();
        await tester.pumpAndSettle();
        // Long names and the followed state must not push this control away
        // from the author or overlap the action column.
        final originalOwner = intro.videoDetail.value.owner;
        intro.videoDetail.value.owner = Owner(
          mid: 1,
          name: '测试创作者的特别长的名字用于窄屏与大字号检查',
          face: '',
        );
        intro.videoDetail.refresh();
        intro.followStatus.value = RelationData(attribute: 2);
        await tester.pumpAndSettle();
        expect(find.text('已关注'), findsOneWidget);
        expect(
          tester.getRect(follow).left - tester.getRect(author).right,
          closeTo(8, .1),
        );
        expect(
          tester.getRect(follow).right,
          lessThanOrEqualTo(size.width - ShortVideoMetrics.informationRight),
        );
        expect(tester.takeException(), isNull);
        intro.videoDetail.value.owner = originalOwner;
        intro.videoDetail.refresh();
        intro.followStatus.value = RelationData(attribute: 0);
        await tester.pumpAndSettle();
        const renderPath = String.fromEnvironment('SHORTS_RENDER_PATH');
        if (renderPath.isNotEmpty) {
          await tester.runAsync(() async {
            final boundary =
                captureKey.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            final image = await _captureAtNativeSize(
              boundary,
              effectiveDpr,
              scenario.size,
            );
            expect(image.width, scenario.size.width.ceil());
            expect(image.height, scenario.size.height.ceil());
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '$renderPath-$previewSuffix.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        // Adjacent first-frame placeholders use the same video rectangle,
        // including footer reservation. No vertical jump at cover/live handoff.
        final covers = find.byWidgetPredicate(
          (w) => w is NetworkImgLayer && w.src == '' && w.type != .avatar,
          skipOffstage: false,
        );
        expect(covers, findsNWidgets(2));
        final mediaSize = tester.getSize(find.byType(_PlayerFixture));
        for (final element in covers.evaluate()) {
          expect(
            tester.getSize(find.byWidget(element.widget, skipOffstage: false)),
            mediaSize,
          );
        }
        final state = playerKey.currentState;
        final progress = find.byType(ProgressBar);
        final barRect = tester.getRect(progress);
        expect(barRect.height, 28);
        // No 600dp cap in the 600..720dp interval (Mate XTs double fold).
        expect(barRect.left, closeTo(ShortVideoMetrics.gutter, .01));
        expect(
          barRect.right,
          closeTo(size.width - ShortVideoMetrics.gutter, .01),
        );
        final playerRect = tester.getRect(find.byType(_PlayerFixture));
        player.playerStatus = PlayerStatus.playing;
        for (final listener in player.listeners.toList()) {
          listener(PlayerStatus.playing);
        }
        video.shortChromeVisible.value = false;
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<ShortVideoChrome>(find.byType(ShortVideoChrome).first)
              .visible,
          isFalse,
        );
        expect(find.byType(ShortVideoMinimalControls), findsOneWidget);
        expect(progress.hitTestable(), findsOneWidget);
        expect(tester.getRect(progress), barRect);
        expect(tester.getRect(find.byType(_PlayerFixture)), playerRect);
        final pauseRect = tester.getRect(find.byIcon(Icons.pause_rounded));
        expect(
          pauseRect.top,
          greaterThanOrEqualTo(
            size.height -
                insets.bottom -
                metrics.controlHeight -
                metrics.playbackHeight,
          ),
        );
        expect(pauseRect.left, greaterThanOrEqualTo(barRect.left));
        expect(pauseRect.bottom, lessThanOrEqualTo(barRect.top + 2));
        await tester.drag(progress, const Offset(50, 0));
        await tester.pumpAndSettle();
        expect(player.seeks, isNotEmpty);
        final seekCount = player.seeks.length;
        await tester.tapAt(
          // A tap ten logical pixels away from the thin painted line still seeks.
          Offset(barRect.left + barRect.width * .3, barRect.center.dy + 10),
        );
        await tester.pumpAndSettle();
        expect(player.seeks.length, seekCount + 1);
        expect(progress.hitTestable(), findsOneWidget);
        expect(video.shortChromeVisible.value, isFalse);
        expect(playerKey.currentState, same(state));
        player.playerStatus = PlayerStatus.paused;
        for (final listener in player.listeners.toList()) {
          listener(PlayerStatus.paused);
        }
        await tester.pumpAndSettle();
        expect(video.shortChromeVisible.value, isFalse);
        expect(
          tester
              .widget<ShortVideoChrome>(find.byType(ShortVideoChrome).first)
              .visible,
          isFalse,
        );
        expect(find.byType(ShortVideoPausedControls), findsNothing);
        expect(
          tester
              .widget<ShortVideoMinimalControls>(
                find.byType(ShortVideoMinimalControls),
              )
              .showPlayback,
          isTrue,
        );
        expect(tester.getRect(progress), barRect);
        // Toggling playback never overrides the visibility chosen by a tap.
        await tester.tap(find.byTooltip('播放'));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        expect(player.playerStatus, PlayerStatus.playing);
        expect(video.shortChromeVisible.value, isFalse);
        expect(player.toggles, 1);
        video.shortChromeVisible.value = true;
        player.playerStatus = PlayerStatus.paused;
        for (final listener in player.listeners.toList()) {
          listener(PlayerStatus.paused);
        }
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<ShortVideoChrome>(find.byType(ShortVideoChrome).first)
              .visible,
          isTrue,
        );
        expect(find.byType(ShortVideoPausedControls), findsOneWidget);
        expect(find.byTooltip('继续播放').hitTestable(), findsOneWidget);
        expect(
          tester
              .widget<ShortVideoMinimalControls>(
                find.byType(ShortVideoMinimalControls),
              )
              .showPlayback,
          isFalse,
        );
        final resumeRect = tester.getRect(find.byTooltip('继续播放'));
        expect(playerRect.contains(resumeRect.topLeft), isTrue);
        expect(playerRect.contains(resumeRect.bottomRight), isTrue);
        expect(tester.getRect(progress), barRect);
        expect(tester.getRect(find.byType(_PlayerFixture)), playerRect);
        expect(progress.hitTestable(), findsOneWidget);
        expect(playerKey.currentState, same(state));
        if (renderPath.isNotEmpty) {
          await tester.runAsync(() async {
            final boundary =
                captureKey.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            final image = await _captureAtNativeSize(
              boundary,
              effectiveDpr,
              scenario.size,
            );
            expect(image.width, scenario.size.width.ceil());
            expect(image.height, scenario.size.height.ceil());
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '$renderPath-paused-$previewSuffix.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        // Paused scrubbing keeps a single timestamp and does not resume.
        player.onSeekStart(80);
        await tester.pumpAndSettle();
        expect(find.byType(ShortVideoPausedControls), findsNothing);
        expect(tester.getRect(progress), barRect);
        expect(
          tester
              .widget<ShortVideoChrome>(find.byType(ShortVideoChrome).first)
              .visible,
          isFalse,
        );
        expect(player.playerStatus, PlayerStatus.paused);
        expect(progress.hitTestable(), findsOneWidget);
        player.onSeekEnd();
        await tester.pumpAndSettle();
        expect(find.byType(ShortVideoPausedControls), findsOneWidget);
        // Loading or an uninitialized stream must not look like a user pause.
        player.isBuffering.value = true;
        await tester.pumpAndSettle();
        expect(find.byType(ShortVideoPausedControls), findsNothing);
        player.isBuffering.value = false;
        player.duration.value = 0;
        await tester.pumpAndSettle();
        expect(find.byType(ShortVideoPausedControls), findsNothing);
        player.duration.value = 1315;
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('继续播放'));
        await tester.pumpAndSettle();
        expect(player.playerStatus, PlayerStatus.playing);
        expect(player.resumes, 1);
        expect(player.toggles, 1);
        expect(find.byType(ShortVideoPausedControls), findsNothing);
        expect(video.shortChromeVisible.value, isTrue);
        expect(
          tester
              .widget<ShortVideoChrome>(find.byType(ShortVideoChrome).first)
              .visible,
          isTrue,
        );
        expect(playerKey.currentState, same(state));
        player.playerStatus = PlayerStatus.paused;
        for (final listener in player.listeners.toList()) {
          listener(PlayerStatus.paused);
        }
        commentsOpen = true;
        await tester.pumpWidget(build(false));
        await tester.pumpAndSettle();
        expect(playerKey.currentState, same(state));
        expect(find.byType(ShortVideoControls), findsOneWidget);
        expect(find.byType(ProgressBar).hitTestable(), findsOneWidget);
        expect(
          tester.widget<ShortVideoPager>(find.byType(ShortVideoPager)).enabled,
          isTrue,
        );
        final commentPlay = find.byIcon(Icons.play_arrow_rounded).hitTestable();
        expect(
          commentPlay,
          findsOneWidget,
          reason: 'Comments playback control: $scenario',
        );
        await tester.tap(commentPlay);
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        expect(player.playerStatus, PlayerStatus.playing);
        expect(find.byIcon(Icons.pause_rounded).hitTestable(), findsOneWidget);
        expect(find.byType(ShortVideoPausedControls), findsNothing);
        final pager = find.byType(PageView);
        final swipeDistance = tester.getSize(pager).height * .8;
        await tester.dragFrom(
          tester.getCenter(find.byType(_PlayerFixture)),
          Offset(0, -swipeDistance),
        );
        await tester.pumpAndSettle();
        expect(
          session.index,
          1,
          reason: 'Video paging remains enabled beside comments',
        );
        expect(find.text('评论内容（布局测试）'), findsOneWidget);
        await tester.dragFrom(
          tester.getCenter(find.byType(_PlayerFixture)),
          Offset(0, swipeDistance),
        );
        await tester.pumpAndSettle();
        expect(session.index, 0);
        expect(playerKey.currentState, same(state));
        final commentBox = tester.getRect(find.text('评论内容（布局测试）'));
        expect(
          tester.getRect(find.byType(_PlayerFixture)).overlaps(commentBox),
          false,
        );
        if (renderPath.isNotEmpty) {
          await tester.runAsync(() async {
            final image = await _captureAtNativeSize(
              captureKey.currentContext!.findRenderObject()
                  as RenderRepaintBoundary,
              effectiveDpr,
              scenario.size,
            );
            expect(image.width, scenario.size.width.ceil());
            expect(image.height, scenario.size.height.ceil());
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '$renderPath-comments-$previewSuffix.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        commentsOpen = false;
        await tester.pumpWidget(build(false));
        await tester.pumpAndSettle();
        expect(playerKey.currentState, same(state));
        expect(tester.getRect(find.byType(_PlayerFixture)), playerRect);
        video.shortChromeVisible.value = true;
        await tester.pumpWidget(build(true));
        await tester.pumpAndSettle();
        expect(playerKey.currentState, same(state));
        expect(find.byType(ShortVideoControls), findsNothing);
        expect(find.byType(ShortVideoPausedControls), findsNothing);
        expect(find.text('评论'), findsOneWidget);
        await tester.drag(find.byType(PageView), Offset(0, -size.height * .75));
        await tester.pumpAndSettle();
        expect(session.index, 1);
        expect(playerKey.currentState, same(state));
        player.controlsLock.value = true;
        await tester.pumpAndSettle();
        expect(find.text('评论'), findsNothing);
        await tester.drag(find.byType(PageView), Offset(0, size.height * .75));
        await tester.pumpAndSettle();
        expect(session.index, 1);
        player.controlsLock.value = false;
        await tester.pumpWidget(build(false));
        await tester.pumpAndSettle();
        expect(playerKey.currentState, same(state));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        expect(player.listeners, isEmpty);
        session.dispose();
      }
    },
  );
}

// Rasterize the scene directly into the integer device framebuffer. Using
// ceil(logicalWidth * DPR) can add a spurious pixel (1008.0000000001 -> 1009)
// for fractional densities; the device's physical framebuffer is authoritative.
Future<ui.Image> _captureAtNativeSize(
  RenderRepaintBoundary boundary,
  double dpr,
  Size pixels,
) async {
  final layer = boundary.debugLayer! as OffsetLayer;
  final transform = Matrix4.diagonal3Values(dpr, dpr, 1)
    ..translateByDouble(-layer.offset.dx, -layer.offset.dy, 0, 1);
  final builder = ui.SceneBuilder()..pushTransform(transform.storage);
  final scene = layer.buildScene(builder);
  try {
    return await scene.toImage(pixels.width.ceil(), pixels.height.ceil());
  } finally {
    scene.dispose();
  }
}

class _PlayerFixture extends StatefulWidget {
  const _PlayerFixture({
    super.key,
    this.aspectRatio = 9 / 16,
    this.ratioLabel = '9x16',
  });
  final double aspectRatio;
  final String ratioLabel;
  @override
  State<_PlayerFixture> createState() => _PlayerFixtureState();
}

class _PlayerFixtureState extends State<_PlayerFixture> {
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black,
    child: Center(
      child: AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: DecoratedBox(
          key: const ValueKey('fixture-video-frame'),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF53756D), Color(0xFF294354), Color(0xFF705F43)],
            ),
            border: Border.all(color: Colors.white24),
          ),
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 60, 12, 12),
              child: Text(
                '${widget.ratioLabel} · 测试画面',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _FakePlayer implements PlPlayerController {
  @override
  final isBuffering = false.obs;
  @override
  final controlsLock = false.obs;
  @override
  final showControls = true.obs;
  @override
  final enableShowDanmaku = true.obs;
  @override
  final position = 35.obs;
  @override
  final duration = 1315.obs;
  @override
  final buffered = 60.obs;
  @override
  int get progress => isSeeking.value ? seekPosition.value : position.value;
  @override
  PlayerStatus playerStatus = PlayerStatus.playing;
  int resumes = 0;
  @override
  Future<void> play({bool repeat = false, bool hideControls = true}) async {
    resumes++;
    playerStatus = PlayerStatus.playing;
    for (final listener in listeners.toList()) {
      listener(playerStatus);
    }
  }

  int toggles = 0;
  @override
  Future<void> onDoubleTapCenter() async {
    toggles++;
    playerStatus = playerStatus.isPlaying
        ? PlayerStatus.paused
        : PlayerStatus.playing;
    for (final listener in listeners.toList()) {
      listener(playerStatus);
    }
  }

  @override
  final seekPosition = 0.obs;
  @override
  final isSeeking = false.obs;
  final seeks = <Duration>[];
  @override
  void onSeekStart([int? seconds]) {
    seekPosition.value = seconds ?? position.value;
    isSeeking.value = true;
  }

  @override
  void onSeekEnd() {
    isSeeking.value = false;
  }

  @override
  Future<void> seekTo(Duration duration, {bool isSeek = true}) async {
    seeks.add(duration);
  }

  final listeners = <dynamic>[];
  @override
  void addStatusLister(dynamic callback) => listeners.add(callback);
  @override
  void removeStatusLister(dynamic callback) => listeners.remove(callback);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeVideo implements VideoDetailController {
  @override
  String? preloadedFirstFrame(String bvid, {int? cid}) => '';
  @override
  final shortPreviewRevision = 0.obs;
  @override
  final shortChromeVisible = true.obs;
  @override
  Future<void> preloadShortWindow(List<ShortVideoEntry> entries) async {
    warmRequests++;
    await pendingWarm;
  }

  int warmRequests = 0;
  Future<void>? pendingWarm;
  _FakeVideo(this.plPlayerController);
  @override
  final PlPlayerController plPlayerController;
  @override
  bool get autoPlay => true;
  int sendPanelOpens = 0;
  @override
  Future<void> showShootDanmakuSheet() async {
    sendPanelOpens++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeIntro implements UgcIntroController {
  @override
  final Rx<List<VideoTagItem>?> videoTags = Rx<List<VideoTagItem>?>([
    VideoTagItem(tagName: '折叠屏体验'),
  ]);
  @override
  final videoDetail = VideoDetailData(
    bvid: 'a',
    pages: [
      Part(cid: 1, part: '第一节'),
      Part(cid: 2, part: '第二节'),
    ],
    title: '很长的视频标题：从单屏展开到三屏时依然可以查看所有操作',
    owner: Owner(mid: 1, name: '测试创作者', face: ''),
    stat: VideoStat.fromJson({
      'view': 77000,
      'like': 14000,
      'reply': 133,
      'coin': 584,
      'favorite': 8312,
      'share': 297,
    }),
  ).obs;
  @override
  final followStatus = RelationData(attribute: 0).obs;
  @override
  final userStat = MemberCardInfoData(follower: 2945000).obs;
  @override
  final total = '11'.obs;
  @override
  final hasLike = false.obs;
  @override
  final hasFav = false.obs;
  @override
  final coinNum = RxNum(0);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
