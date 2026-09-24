import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:PiliPlus/pages/mine/widgets/item.dart';
import 'package:PiliPlus/models_new/fav/fav_folder/list.dart';
import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:PiliPlus/harmony_adapt/qa_profile.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models_new/history/data.dart';
import 'package:PiliPlus/models_new/history/history.dart';
import 'package:PiliPlus/models_new/history/list.dart';
import 'package:PiliPlus/pages/mine/recent_history.dart';
import 'package:PiliPlus/pages/mine/widgets/recent_history.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

HistoryItemModel item(int i) => HistoryItemModel(
  title: '最近观看 $i：很长的视频标题，继续上次观看的进度',
  history: History(
    oid: i + 1,
    bvid: 'BV1xx411c7mD',
    cid: 123,
    business: 'archive',
  ),
  progress: i == 0 ? -1 : 120,
  duration: 3600,
  authorName: '作者',
);
Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  late Directory temp;
  setUpAll(() async {
    temp = await Directory.systemTemp.createTemp('piliplus-history-test-');
    Hive.init(temp.path);
    GStorage.setting = await Hive.openBox('setting');
    for (final font in [
      ('preview', const String.fromEnvironment('SHORTS_PREVIEW_FONT')),
      ('preview-cjk', const String.fromEnvironment('SHORTS_PREVIEW_CJK_FONT')),
      ('MaterialIcons', const String.fromEnvironment('SHORTS_PREVIEW_ICONS')),
    ]) {
      if (font.$2.isNotEmpty) {
        await (FontLoader(font.$1)
              ..addFont(File(font.$2).readAsBytes().then(ByteData.sublistView)))
            .load();
      }
    }
  });
  tearDownAll(() async {
    await Hive.close();
    await temp.delete(recursive: true);
  });

  test('preview is opt-in, guest-safe, bounded and refreshable', () async {
    final state = RecentHistory();
    addTearDown(state.dispose);
    final owner = Object();
    var requests = 0;
    Future<LoadingState<HistoryData>> load() async {
      requests++;
      return Success(HistoryData(list: List.generate(20, item)));
    }

    state.configure(enabled: false, account: owner, load: load);
    await state.refresh();
    state.configure(enabled: true, account: null, load: load);
    await state.refresh();
    expect(requests, 0);
    state.configure(enabled: true, account: owner, load: load);
    await flush();
    expect(requests, 1);
    expect(state.items.length, 10);
    expect(state.items.first.playbackProgress, 0);
    expect(state.items[1].playbackProgress, 120000);
    state.configure(enabled: true, account: owner, load: load);
    expect(requests, 1);
    await state.refresh();
    expect(requests, 2);
    state.configure(enabled: false, account: owner, load: load);
    expect(state.items, isEmpty);
  });

  test(
    'account changes, disabling and disposal reject stale history responses',
    () async {
      final state = RecentHistory();
      final a = Completer<LoadingState<HistoryData>>();
      final b = Completer<LoadingState<HistoryData>>();
      state
        ..configure(enabled: true, account: Object(), load: () => a.future)
        ..configure(enabled: true, account: Object(), load: () => b.future);
      b.complete(Success(HistoryData(list: [item(2)])));
      await flush();
      a.complete(Success(HistoryData(list: [item(1)])));
      await flush();
      expect(state.items.single.history.oid, 3);
      final pending = Completer<LoadingState<HistoryData>>();
      state
        ..configure(
          enabled: true,
          account: Object(),
          load: () => pending.future,
        )
        ..configure(enabled: true, account: null, load: () => pending.future);
      expect(state.items, isEmpty);
      pending.complete(Success(HistoryData(list: [item(3)])));
      await flush();
      expect(state.items, isEmpty);
      final disposed = Completer<LoadingState<HistoryData>>();
      state
        ..configure(
          enabled: true,
          account: Object(),
          load: () => disposed.future,
        )
        ..dispose();
      disposed.complete(Success(HistoryData(list: [item(4)])));
      await flush();
    },
  );

  test(
    'request failures allow retry and suppress duplicate in-flight requests',
    () async {
      final state = RecentHistory();
      addTearDown(state.dispose);
      final pending = Completer<LoadingState<HistoryData>>();
      var count = 0;
      state.configure(
        enabled: true,
        account: Object(),
        load: () {
          count++;
          return count == 1
              ? pending.future
              : Future.value(Success(HistoryData(list: [])));
        },
      );
      await state.refresh();
      expect(count, 1);
      pending.completeError(StateError('offline'));
      await flush();
      expect(state.error, isNotNull);
      expect(state.loading, isFalse);
      await state.refresh();
      expect(count, 2);
      expect(state.error, isNull);
    },
  );

  test('guest test profile leaves production storage paths unchanged', () {
    expect(QaProfile.guest, isFalse);
    expect(QaProfile.directory('/app/files'), '/app/files');
    expect(
      QaProfile.directory('/app/files', isolated: true),
      '/app/files/qa-guest-v1',
    );
  });

  testWidgets(
    'history preview fits native sizes, themes and large fonts; guest login and resume work',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = RecentHistory();
      addTearDown(state.dispose);
      var opened = 0, all = 0, login = 0;
      final owner = Object();
      Future<LoadingState<HistoryData>> load() async =>
          Success(HistoryData(list: List.generate(10, item)));
      for (final size in [
        const Size(1008, 2232),
        const Size(2048, 2232),
        const Size(3184, 2232),
      ]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 2.875;
        for (final scale in [1.0, 1.3, 2.0]) {
          for (final dark in [false, true]) {
            for (final harmony in [false, true]) {
              var theme = ThemeData(
                brightness: dark ? Brightness.dark : Brightness.light,
              );
              theme = theme.copyWith(
                textTheme: theme.textTheme.apply(
                  fontFamily: 'preview',
                  fontFamilyFallback: ['preview-cjk'],
                ),
              );
              if (harmony) theme = HarmonyTheme.apply(theme);
              final capture = GlobalKey();
              state.configure(enabled: true, account: owner, load: load);
              await tester.pumpWidget(
                MaterialApp(
                  theme: theme,
                  home: RepaintBoundary(
                    key: capture,
                    child: MediaQuery(
                      data: MediaQueryData(
                        size: size / 2.875,
                        devicePixelRatio: 2.875,
                        textScaler: TextScaler.linear(scale),
                        padding: const EdgeInsets.only(top: 36, bottom: 24),
                      ),
                      child: Scaffold(
                        body: SafeArea(
                          child: ListView(
                            children: [
                              MineHistoryPreview(
                                expanded: harmony && size.width >= 3184,
                                history: state,
                                onOpen: (_) => opened++,
                                onViewAll: () => all++,
                                onLogin: () => login++,
                              ),
                            ],
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
                reason: '$size scale=$scale dark=$dark harmony=$harmony',
              );
              if (harmony && dark && scale == 1.0) {
                await _capture(
                  tester,
                  capture,
                  'history-${size.width.toInt()}',
                  size,
                  2.875,
                );
              }
              expect(
                find.byTooltip('刷新观看历史'),
                size.width / 2.875 < 600 ? findsNothing : findsOneWidget,
              );
              final card = find.textContaining('最近观看 0').first;
              await tester.tap(card);
              await tester.pump();
              expect(opened, greaterThan(0));
              await tester.tap(find.text('观看历史'));
              await tester.pump();
              expect(all, greaterThan(0));
            }
          }
        }
      }
      state.configure(enabled: true, account: null, load: load);
      await tester.pumpAndSettle();
      expect(find.textContaining('最近观看'), findsNothing);
      await tester.tap(find.text('登录后查看观看历史'));
      expect(login, 1);
      state.configure(enabled: false, account: null, load: load);
      await tester.pumpAndSettle();
      expect(find.text('观看历史'), findsNothing);
    },
  );
  testWidgets(
    'favorite card constrains long titles and counts at large font scales',
    (tester) async {
      for (final scale in [1.0, 1.3, 2.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: SizedBox(
                  height: 148 + scale * (14 + 11) * 1.5,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      FavFolderItem(
                        item: FavFolderInfo(
                          title: '很长的收藏夹名称，用来检查横向卡片的边界',
                          mediaCount: 100000000,
                        ),
                        onPop: () {},
                        heroTag: 'test-folder',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.getSize(find.byType(FavFolderItem)).width, 180);
        expect(
          tester.takeException(),
          isNull,
          reason: 'favorite text scale $scale',
        );
      }
    },
  );
}

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
