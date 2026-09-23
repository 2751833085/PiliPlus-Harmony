import 'dart:io';
import 'package:PiliPlus/common/assets.dart';
import 'dart:ui' as ui;
import 'package:PiliPlus/common/widgets/dialog/bottom_panel.dart';
import 'package:PiliPlus/harmony_adapt/harmony_channel.dart';
import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:PiliPlus/harmony_adapt/window_layout.dart';
import 'package:PiliPlus/harmony_adapt/widgets/harmony_hand_dock.dart';
import 'package:PiliPlus/harmony_adapt/widgets/harmony_quick_actions.dart';
import 'package:PiliPlus/pages/about/harmony_about.dart';
import 'package:PiliPlus/pages/video/shorts/panel_theme.dart';
import 'package:PiliPlus/pages/video/widgets/player_menu.dart';
import 'package:PiliPlus/plugin/pl_player/widgets/control_bar.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

const _profiles = [Size(1008, 2232), Size(2048, 2232), Size(3184, 2232)];

Future<void> _capture(
  WidgetTester tester,
  GlobalKey key,
  String name,
  Size pixels,
  double dpr,
) async {
  const path = String.fromEnvironment('SHORTS_RENDER_PATH');
  if (path.isEmpty) return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final layer = boundary.debugLayer! as OffsetLayer;
    final transform = Matrix4.diagonal3Values(dpr, dpr, 1)
      ..translateByDouble(-layer.offset.dx, -layer.offset.dy, 0, 1);
    final scene = layer.buildScene(
      ui.SceneBuilder()..pushTransform(transform.storage),
    );
    final image = await scene.toImage(
      pixels.width.toInt(),
      pixels.height.toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$path-$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
    scene.dispose();
  });
}

void main() {
  setUpAll(() async {
    for (final font in [
      ('preview', const String.fromEnvironment('SHORTS_PREVIEW_FONT')),
      ('preview-cjk', const String.fromEnvironment('SHORTS_PREVIEW_CJK_FONT')),
      ('MaterialIcons', const String.fromEnvironment('SHORTS_PREVIEW_ICONS')),
    ]) {
      if (font.$2.isEmpty) continue;
      final loader = FontLoader(font.$1)
        ..addFont(File(font.$2).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
  });
  tearDown(Get.reset);

  testWidgets(
    'short menus fit their content and large menus remain scrollable',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final pixels in _profiles) {
        tester.view.physicalSize = pixels;
        tester.view.devicePixelRatio = 2.875;
        for (final count in [3, 30]) {
          var called = 0;
          await tester.pumpWidget(
            GetMaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => PageUtils.showVideoBottomSheet(
                      context,
                      fitContent: true,
                      child: BottomPanel(
                        title: '选择',
                        fitContent: true,
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            for (var i = 0; i < count; i++)
                              ListTile(
                                title: Text('选项 $i'),
                                onTap: () => called++,
                              ),
                          ],
                        ),
                      ),
                    ),
                    child: const Text('打开'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('打开'));
          await tester.pumpAndSettle();
          final size = pixels / 2.875;
          final rect = tester.getRect(find.byType(BottomPanel));
          expect(rect.bottom, closeTo(size.height, .01));
          expect(rect.height, lessThanOrEqualTo(size.height * .78 + .01));
          if (count == 3) expect(rect.height, lessThan(size.height * .55));
          final last = find.text('选项 ${count - 1}');
          await tester.scrollUntilVisible(
            last,
            250,
            scrollable: find.byType(Scrollable).last,
          );
          await tester.tap(last);
          expect(called, 1);
          expect(tester.takeException(), isNull);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          await tester.pumpWidget(const SizedBox());
        }
      }
    },
  );

  testWidgets(
    'video menu captures the local dark theme, stays attached to the bottom and closes before its action',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final pixels in _profiles) {
        for (final density
            in pixels.width == 3184 ? [2.875] : [2.5, 2.875, 3.25]) {
          for (final scale in [1.0, 1.3, 2.0]) {
            tester.view.physicalSize = pixels;
            tester.view.devicePixelRatio = density;
            final capture = GlobalKey();
            var selected = 0;
            ThemeData? inherited;
            final videoTheme = shortVideoPanelTheme(
              HarmonyTheme.apply(
                ThemeData(
                  brightness: Brightness.dark,
                  fontFamily: 'preview',
                  fontFamilyFallback: const ['preview-cjk'],
                ),
                immersive: true,
              ),
            );
            await tester.pumpWidget(
              GetMaterialApp(
                theme: ThemeData.light(),
                builder: (_, child) => MediaQuery(
                  data: MediaQueryData.fromView(tester.view).copyWith(
                    textScaler: TextScaler.linear(scale),
                    viewPadding: const EdgeInsets.only(bottom: 24),
                  ),
                  child: RepaintBoundary(key: capture, child: child!),
                ),
                home: Theme(
                  data: videoTheme,
                  child: Builder(
                    builder: (context) => Scaffold(
                      backgroundColor: Colors.black,
                      body: Center(
                        child: TextButton(
                          onPressed: () => PageUtils.showVideoBottomSheet(
                            context,
                            maxWidth: 640,
                            child: Builder(
                              builder: (context) {
                                inherited = Theme.of(context);
                                return BottomPanel(
                                  title: '视频与播放',
                                  child: PlayerMenu(
                                    actions: [
                                      for (final action in const [
                                        ('我不想看', Icons.not_interested),
                                        ('稍后再看', Icons.watch_later_outlined),
                                        ('离线缓存', Icons.download_outlined),
                                        ('笔记', Icons.note_alt_outlined),
                                        ('小窗播放', Icons.picture_in_picture_alt),
                                        ('投屏', Icons.cast),
                                      ])
                                        PlayerMenuAction(
                                          action.$1,
                                          action.$2,
                                          () {
                                            Navigator.pop(context);
                                            selected++;
                                          },
                                        ),
                                    ],
                                    children: [
                                      for (final name in [
                                        '倍速',
                                        '选集 / 分 P',
                                        '章节',
                                        '字幕',
                                        '字幕翻译',
                                        '画质',
                                        '画面比例',
                                        '弹幕设置',
                                        '更多播放设置',
                                      ])
                                        PlayerMenuRow(
                                          title: name,
                                          icon: Icons.tune,
                                          onTap: () {},
                                          value: name == '倍速' ? '1.0 倍' : null,
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          child: const Text('打开菜单'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.tap(find.text('打开菜单'));
            await tester.pumpAndSettle();
            expect(inherited!.brightness, Brightness.dark);
            expect(inherited!.extension<PopupSurfaceStyle>(), isNotNull);
            expect(find.byType(BackdropFilter), findsOneWidget);
            final rect = tester.getRect(find.byType(BottomPanel));
            expect(rect.bottom, closeTo(pixels.height / density, .01));
            expect(rect.center.dx, closeTo(pixels.width / density / 2, .01));
            expect(tester.takeException(), isNull);
            if (density == 2.875 && scale == 1) {
              await _capture(
                tester,
                capture,
                'menu-${pixels.width.toInt()}',
                pixels,
                density,
              );
            }
            await tester.tap(find.text('稍后再看'));
            await tester.pumpAndSettle();
            expect(selected, 1);
            expect(find.byType(BottomPanel), findsNothing);
            await tester.tap(find.text('打开菜单'));
            await tester.pumpAndSettle();
            await tester.binding.handlePopRoute();
            await tester.pumpAndSettle();
            expect(find.text('打开菜单'), findsOneWidget);
            expect(selected, 1);
            await tester.pumpWidget(const SizedBox());
            await tester.pumpAndSettle();
          }
        }
      }
    },
  );

  testWidgets(
    'menu callbacks and disabled choices survive sheet mode; normal mode remains a popup',
    (tester) async {
      final semantics = tester.ensureSemantics();
      for (final harmony in [false, true]) {
        var opened = 0, canceled = 0, selected = 0, direct = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: harmony
                ? HarmonyTheme.apply(ThemeData.dark(), immersive: true)
                : ThemeData.dark(),
            home: Scaffold(
              body: Center(
                child: PopupMenuButton<int>(
                  tooltip: '选择字幕',
                  onOpened: () => opened++,
                  onCanceled: () => canceled++,
                  onSelected: (value) => selected = value,
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 1,
                      enabled: false,
                      child: Text('不可用'),
                    ),
                    PopupMenuItem(
                      value: 2,
                      onTap: () => direct++,
                      child: const Text('简体中文'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('选择字幕'));
        await tester.pumpAndSettle();
        expect(
          find.byType(ImmersiveSurface),
          harmony ? findsOneWidget : findsNothing,
        );
        await tester.tap(find.text('不可用'));
        await tester.pumpAndSettle();
        expect(selected, 0);
        expect(direct, 0);
        await tester.tap(find.text('简体中文'));
        await tester.pumpAndSettle();
        expect(selected, 2);
        expect(direct, 1);
        expect(opened, 1);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('选择字幕'));
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(canceled, 1);
        expect(opened, 2);
        expect(tester.takeException(), isNull);
      }
      semantics.dispose();
    },
  );

  testWidgets('high contrast and disabled immersion use opaque backgrounds', (
    tester,
  ) async {
    for (final immersive in [false, true]) {
      for (final contrast in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: HarmonyTheme.apply(ThemeData.dark(), immersive: immersive),
            home: MediaQuery(
              data: MediaQueryData(highContrast: contrast),
              child: const ImmersiveSurface(
                blurBackground: true,
                child: SizedBox(width: 300, height: 200),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(BackdropFilter),
          immersive && !contrast ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets(
    'fullscreen seek bar spans the native triple viewport for both hands',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final previous = HarmonyChannel.handSide.value;
      addTearDown(() => HarmonyChannel.handSide.value = previous);
      tester.view.physicalSize = _profiles.last;
      tester.view.devicePixelRatio = 2.875;
      const width = 3184 / 2.875;
      for (final side in HarmonyHandSide.values) {
        HarmonyChannel.handSide.value = side;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: HarmonyHandDock(
                  enabled: true,
                  preserveWidth: true,
                  width: width,
                  builder: (_) => CompactPlayerControlBar(
                    play: const SizedBox(width: 40, height: 40),
                    progress: const SizedBox(key: ValueKey('seek'), height: 40),
                    time: const PlayerControlTime(
                      position: '00:23',
                      duration: '18:10',
                    ),
                    actions: const [SizedBox(width: 40, height: 40)],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byType(CompactPlayerControlBar)).width,
          closeTo(width, .01),
        );
        expect(tester.getRect(find.byKey(const ValueKey('seek'))).left, 40);
        expect(
          tester.getSize(find.byKey(const ValueKey('seek'))).width,
          greaterThan(width * .75),
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  test(
    'triple fullscreen title ignores DPI changes but not ordinary pages or folded states',
    () {
      for (final density in [2.5, 2.875, 3.25]) {
        expect(
          HarmonyWindowLayout.hideExpandedFullscreenTitle(
            harmony: true,
            fullscreen: true,
            expanded: true,
            longestPhysicalSide: (3184 / density) * density,
          ),
          true,
        );
      }
      for (final state in [
        (true, true, false, 3184.0),
        (true, false, true, 3184.0),
        (true, true, true, 2232.0),
        (false, true, true, 3184.0),
      ]) {
        expect(
          HarmonyWindowLayout.hideExpandedFullscreenTitle(
            harmony: state.$1,
            fullscreen: state.$2,
            expanded: state.$3,
            longestPhysicalSide: state.$4,
          ),
          false,
        );
      }
    },
  );

  testWidgets(
    'compact shortcuts and about credit fit native profiles and large text',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final pixels in _profiles) {
        for (final scale in [1.0, 1.3, 2.0]) {
          tester.view.physicalSize = pixels;
          tester.view.devicePixelRatio = 2.875;
          final capture = GlobalKey();
          var taps = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: HarmonyTheme.apply(
                ThemeData(
                  brightness: Brightness.dark,
                  fontFamily: 'preview',
                  fontFamilyFallback: const ['preview-cjk'],
                ),
                immersive: true,
              ),
              home: MediaQuery(
                data: MediaQueryData.fromView(
                  tester.view,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: RepaintBoundary(
                  key: capture,
                  child: Scaffold(
                    body: SafeArea(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              ImmersiveSurface(
                                child: HarmonyQuickActions(
                                  actions: [
                                    for (final label in [
                                      '离线缓存',
                                      '观看记录',
                                      '我的订阅',
                                      '稍后再看',
                                    ])
                                      HarmonyQuickAction(
                                        label,
                                        Icons.play_circle_outline,
                                        () => taps++,
                                      ),
                                  ],
                                ),
                              ),
                              HarmonyAboutHeader(
                                version: '2.6.12+6098',
                                onLogoTap: () => taps++,
                              ),
                              const HarmonyDevelopmentJourney(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.runAsync(
            () => precacheImage(
              const AssetImage(Assets.logo),
              capture.currentContext!,
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('厄斯因二次编辑'), findsOneWidget);
          for (final label in ['离线缓存', '观看记录', '我的订阅', '稍后再看'])
            await tester.tap(find.text(label));
          expect(taps, 4);
          expect(tester.takeException(), isNull);
          if (scale == 1)
            await _capture(
              tester,
              capture,
              'about-${pixels.width.toInt()}',
              pixels,
              2.875,
            );
        }
      }
    },
  );
}
