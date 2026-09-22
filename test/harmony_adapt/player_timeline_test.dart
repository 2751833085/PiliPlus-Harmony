import 'package:flutter/foundation.dart';
import 'package:PiliPlus/common/widgets/player_bar.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:PiliPlus/common/widgets/progress_bar/audio_video_progress_bar.dart';
import 'package:PiliPlus/common/widgets/progress_bar/segment_progress_bar.dart';
import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/pages/video/controller.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/widgets/bottom_control.dart';
import 'package:PiliPlus/plugin/pl_player/widgets/control_bar.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';

void main() {
  late Directory temp;
  setUpAll(() async {
    temp = await Directory.systemTemp.createTemp('timeline-test-');
    Hive.init(temp.path);
    GStorage.setting = await Hive.openBox('setting');
    const font = String.fromEnvironment('SHORTS_PREVIEW_FONT');
    if (font.isNotEmpty) {
      await (FontLoader(
        'preview',
      )..addFont(File(font).readAsBytes().then(ByteData.sublistView))).load();
    }
    const icons = String.fromEnvironment('SHORTS_PREVIEW_ICONS');
    if (icons.isNotEmpty) {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(File(icons).readAsBytes().then(ByteData.sublistView))).load();
    }
  });
  tearDownAll(() async {
    await Hive.close();
    await temp.delete(recursive: true);
  });

  testWidgets(
    'native density normal player keeps one-line time, aligned segments and working seek callbacks',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        // Triple DPR is measured; single/double are explicit density scan inputs.
        for (final physical in [
          const Size(1008, 2232),
          const Size(2048, 2232),
          const Size(3184, 2232),
        ]) {
          for (final density
              in physical.width == 3184 ? [2.875] : [2.5, 2.875, 3.25]) {
            for (final scale in [1.0, 1.3, 2.0]) {
              for (final compact in [false, true]) {
                tester.view.physicalSize = physical;
                tester.view.devicePixelRatio = density;
                await tester.runAsync(
                  () => GStorage.setting.put('biliPlayerControls', compact),
                );
                final player = _Player();
                final video = _Video(player);
                final capture = GlobalKey();
                final semantics = tester.ensureSemantics();
                await tester.pumpWidget(
                  MaterialApp(
                    theme: HarmonyTheme.apply(
                      ThemeData.dark().copyWith(
                        textTheme: ThemeData.dark().textTheme.apply(
                          fontFamily: 'preview',
                        ),
                      ),
                    ),
                    home: RepaintBoundary(
                      key: capture,
                      child: Builder(
                        builder: (context) => MediaQuery(
                          data: MediaQueryData.fromView(
                            tester.view,
                          ).copyWith(textScaler: TextScaler.linear(scale)),
                          child: Scaffold(
                            backgroundColor: const Color(0xff151b25),
                            body: Center(
                              child: AspectRatio(
                                aspectRatio: 16 / 9,
                                child: ColoredBox(
                                  color: Colors.black,
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: BottomControl(
                                      maxWidth: physical.width / density,
                                      isFullScreen: false,
                                      controller: player,
                                      videoDetailController: video,
                                      buildBottomControl: (progress) {
                                        final time = Obx(
                                          () => PlayerControlTime(
                                            position:
                                                '${player.position.value ~/ 60}:${(player.position.value % 60).toString().padLeft(2, '0')}',
                                            duration: '1:21:55',
                                          ),
                                        );
                                        final play = SizedBox(
                                          width: 42,
                                          height: 40,
                                          child: IconButton(
                                            icon: const Icon(Icons.pause),
                                            onPressed: () {},
                                          ),
                                        );
                                        final actions = [
                                          for (final icon in [
                                            Icons.stay_current_portrait,
                                            Icons.more_horiz,
                                            Icons.fullscreen,
                                          ])
                                            SizedBox(
                                              width: 36,
                                              height: 40,
                                              child: Icon(icon, size: 20),
                                            ),
                                        ];
                                        return progress == null
                                            ? PlayerBar(
                                                children: [
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [play, time],
                                                  ),
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: actions,
                                                  ),
                                                ],
                                              )
                                            : CompactPlayerControlBar(
                                                play: play,
                                                progress: progress,
                                                time: time,
                                                actions: actions,
                                              );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
                await tester.pumpAndSettle();
                expect(
                  tester.takeException(),
                  isNull,
                  reason: '$physical DPR $density text $scale compact $compact',
                );
                final track = tester.getRect(find.byType(ProgressBar));
                final segment = tester.getRect(find.byType(SegmentProgressBar));
                expect(segment.left, track.left);
                expect(segment.width, track.width);
                expect(segment.center.dy, closeTo(track.center.dy, .001));
                expect(segment.height, compact ? 2 : 3.5);
                expect(track.height, 28);
                expect(track.width, greaterThan(60));
                if (physical.width == 3184 && compact) {
                  expect(
                    track.width,
                    greaterThan(physical.width / density * .5),
                  );
                }
                final text = tester.renderObject<RenderParagraph>(
                  find.descendant(
                    of: find.byType(PlayerControlTime),
                    matching: find.byType(RichText),
                  ),
                );
                expect(text.didExceedMaxLines, false);
                expect(
                  text
                      .getBoxesForSelection(
                        const TextSelection(baseOffset: 0, extentOffset: 4),
                      )
                      .first
                      .top,
                  text
                      .getBoxesForSelection(
                        const TextSelection(baseOffset: 7, extentOffset: 14),
                      )
                      .first
                      .top,
                );
                expect(
                  find.bySemanticsLabel(RegExp('当前时间.*总时长')),
                  findsOneWidget,
                );
                // Decorative segment overlay must not swallow taps or drag callbacks.
                await tester.tapAt(
                  Offset(track.left + track.width * .5, track.center.dy),
                );
                await tester.pump();
                expect(player.seeks.last.inSeconds, closeTo(2457, 2));
                await tester.dragFrom(
                  Offset(track.left + track.width * .25, track.center.dy + 9),
                  Offset(track.width * .5, 0),
                );
                await tester.pump();
                expect(player.starts, greaterThan(0));
                expect(player.ends, greaterThan(0));
                expect(player.seeks.last.inSeconds, greaterThan(2457));
                expect(player.isSeeking.value, false);
                final chapter = tester.getRect(
                  find.byType(ViewPointSegmentProgressBar),
                );
                await tester.tapAt(
                  Offset(chapter.left + chapter.width * .8, chapter.center.dy),
                );
                await tester.pump();
                expect(player.seeks.last, const Duration(seconds: 2400));
                const output = String.fromEnvironment('SHORTS_RENDER_PATH');
                if (output.isNotEmpty &&
                    physical.width == 3184 &&
                    scale == 1 &&
                    compact) {
                  final boundary =
                      capture.currentContext!.findRenderObject()!
                          as RenderRepaintBoundary;
                  await tester.runAsync(() async {
                    final builder = ui.SceneBuilder()
                      ..pushTransform(
                        (Matrix4.identity()
                              ..scaleByDouble(density, density, 1, 1))
                            .storage,
                      );
                    (boundary.debugLayer! as OffsetLayer).addToScene(builder);
                    builder.pop();
                    final scene = builder.build();
                    final image = await scene.toImage(
                      physical.width.toInt(),
                      physical.height.toInt(),
                    );
                    scene.dispose();
                    final bytes = await image.toByteData(
                      format: ui.ImageByteFormat.png,
                    );
                    image.dispose();
                    await File(
                      '$output-normal-triple.png',
                    ).writeAsBytes(bytes!.buffer.asUint8List());
                  });
                }
                // Toggle chapters/trend/segments without stale alignment or a new controller.
                video.showVP.value = false;
                video.showDmTrendChart.value = false;
                video.segmentProgressList.clear();
                await tester.pump();
                expect(find.byType(SegmentProgressBar), findsNothing);
                expect(find.byType(ViewPointSegmentProgressBar), findsNothing);
                expect(find.byType(ProgressBar), findsOneWidget);
                expect(tester.takeException(), isNull);
                semantics.dispose();
                await tester.pumpWidget(const SizedBox());
              }
            }
          }
        }
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}

class _Player implements PlPlayerController {
  @override
  final showControls = true.obs;
  @override
  final position = 35.obs;
  @override
  final duration = 4915.obs;
  @override
  final buffered = 1500.obs;
  @override
  final isSeeking = false.obs;
  @override
  final seekPosition = 0.obs;
  @override
  int get progress => isSeeking.value ? seekPosition.value : position.value;
  @override
  bool get enableBlock => true;
  @override
  bool get showViewPoints => true;
  @override
  bool get isFileSource => false;
  @override
  bool get showSeekPreview => false;
  int starts = 0, ends = 0;
  final seeks = <Duration>[];
  @override
  void onSeekStart(int seconds) {
    starts++;
    seekPosition.value = seconds;
    isSeeking.value = true;
  }

  @override
  void onSeekEnd() {
    ends++;
    isSeeking.value = false;
  }

  @override
  Future<void> seekTo(Duration value, {bool isSeek = true}) async {
    seeks.add(value);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Video implements VideoDetailController {
  _Video(this.plPlayerController);
  @override
  final PlPlayerController plPlayerController;
  @override
  final segmentProgressList = <Segment>[
    const Segment(start: .2, end: .4, color: Colors.green),
  ].obs;
  @override
  final viewPointList = <ViewPointSegment>[
    const ViewPointSegment(end: .5, title: 'A', from: 0),
    const ViewPointSegment(end: 1, title: 'B', from: 2400),
  ].obs;
  @override
  final showVP = true.obs;
  @override
  final showDmTrendChart = true.obs;
  @override
  final dmTrend = Rx<LoadingState<List<double>>?>(
    const Success([.1, .2, .8, .3]),
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
