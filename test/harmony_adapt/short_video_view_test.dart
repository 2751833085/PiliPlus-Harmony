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
    'actual feed fits phone, expanded fold and large text; fullscreen keeps the same player',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final size in const [
        Size(390, 844),
        Size(320, 640),
        Size(840, 800),
        Size(600, 320),
      ]) {
        tester.view.physicalSize = size;
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
        final playerKey = GlobalKey();
        final captureKey = GlobalKey();
        var commentsOpen = false;
        Widget build(bool fullscreen) => MaterialApp(
          theme: ThemeData(
            fontFamily:
                const String.fromEnvironment('SHORTS_PREVIEW_FONT').isEmpty
                ? null
                : 'shorts-preview',
          ),
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(size.width == 390 ? 1 : 1.8),
            ),
            child: RepaintBoundary(
              key: captureKey,
              child: ShortVideoFeed(
                commentsPanel: commentsOpen
                    ? Theme(
                        data: ThemeData(
                          brightness: Brightness.dark,
                          fontFamily: 'shorts-preview',
                        ),
                        child: Material(
                          color: const Color(0xFF17181A),
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
                intro: _FakeIntro(),
                playerBuilder: (_, __) => _PlayerFixture(key: playerKey),
                onDetails: () {},
                onComments: () {},
                onEpisodes: () {},
                onMore: () {},
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
        const renderPath = String.fromEnvironment('SHORTS_RENDER_PATH');
        if (renderPath.isNotEmpty) {
          await tester.runAsync(() async {
            final boundary =
                captureKey.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '$renderPath-${size.width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        // Adjacent covers are already built and use the same video rectangle,
        // including footer reservation. No vertical jump at cover/live handoff.
        final covers = find.byWidgetPredicate(
          (w) => w is NetworkImgLayer && w.src == '',
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
        expect(pauseRect.top, greaterThan(size.height - 130));
        expect(pauseRect.left, greaterThanOrEqualTo(barRect.left));
        expect(pauseRect.bottom, lessThanOrEqualTo(barRect.top + 2));
        await tester.drag(progress, const Offset(50, 0));
        await tester.pumpAndSettle();
        expect(player.seeks, isNotEmpty);
        final seekCount = player.seeks.length;
        await tester.tapAt(
          Offset(barRect.left + barRect.width * .3, barRect.center.dy),
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
        expect(
          tester.getRect(find.byIcon(Icons.play_arrow_rounded)),
          pauseRect,
        );
        expect(progress.hitTestable(), findsOneWidget);
        expect(playerKey.currentState, same(state));
        if (renderPath.isNotEmpty) {
          await tester.runAsync(() async {
            final boundary =
                captureKey.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '$renderPath-minimal-${size.width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        commentsOpen = true;
        await tester.pumpWidget(build(false));
        await tester.pumpAndSettle();
        expect(playerKey.currentState, same(state));
        expect(find.byType(ShortVideoControls), findsNothing);
        final commentBox = tester.getRect(find.text('评论内容（布局测试）'));
        expect(
          tester.getRect(find.byType(_PlayerFixture)).overlaps(commentBox),
          false,
        );
        if (renderPath.isNotEmpty) {
          await tester.runAsync(() async {
            final image =
                await (captureKey.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '$renderPath-comments-${size.width.toInt()}.png',
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

class _PlayerFixture extends StatefulWidget {
  const _PlayerFixture({super.key});
  @override
  State<_PlayerFixture> createState() => _PlayerFixtureState();
}

class _PlayerFixtureState extends State<_PlayerFixture> {
  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Colors.black,
    child: Center(child: Text('player')),
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
  PlayerStatus playerStatus = PlayerStatus.paused;
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
  final shortChromeVisible = true.obs;
  @override
  Future<void> preloadShortWindow(List<ShortVideoEntry> entries) async {}
  _FakeVideo(this.plPlayerController);
  @override
  final PlPlayerController plPlayerController;
  @override
  bool get autoPlay => true;
  @override
  Future<void> showShootDanmakuSheet() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeIntro implements UgcIntroController {
  @override
  final videoDetail = VideoDetailData(
    bvid: 'a',
    title: '很长的视频标题：从单屏展开到三屏时依然可以查看所有操作',
    owner: Owner(mid: 1, name: '测试创作者的较长名字'),
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
