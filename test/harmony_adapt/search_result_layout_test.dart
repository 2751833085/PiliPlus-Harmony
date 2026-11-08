import 'package:PiliPlus/common/widgets/dialog/bottom_panel.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/sliver/sliver_floating_header.dart';
import 'package:PiliPlus/common/widgets/video_card/video_card_h.dart';
import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:PiliPlus/harmony_adapt/widgets/harmony_loading.dart';
import 'package:PiliPlus/http/api.dart';
import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/pages/search/controller.dart';
import 'package:PiliPlus/pages/search/view.dart';
import 'package:PiliPlus/models/common/search/search_type.dart';
import 'package:PiliPlus/pages/search_panel/all/controller.dart';
import 'package:PiliPlus/pages/search_panel/all/view.dart';
import 'package:PiliPlus/pages/search_panel/article/widgets/item.dart';
import 'package:PiliPlus/pages/search_panel/live/widgets/item.dart';
import 'package:PiliPlus/pages/search_panel/pgc/widgets/item.dart';
import 'package:PiliPlus/pages/search_panel/user/widgets/item.dart';
import 'package:PiliPlus/pages/search_result/view.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers/memory_box.dart';

const _single = Size(1008, 2232);
const _double = Size(2048, 2232);
const _triple = Size(3184, 2232);
const _query = '搜索测试词';
const _videoTitle = '这是很长的测试视频标题，用来检查多行文字和各类视频信息的位置';
const _liveTitle = '这是很长的测试直播标题，用来检查两行文本和观看数据的布局';
const _author = '很长很长的作者名字与资料描述';

void main() {
  final calls = <String, int>{};
  late Interceptor mockSearch;

  setUpAll(() async {
    GStorage.setting = MemoryBox();
    GStorage.historyWord = MemoryBox();
    GStorage.localCache = MemoryBox();
    await GStorage.setting.put(SettingBoxKey.searchSuggestion, false);
    await GStorage.localCache.put(
      LocalCacheKey.timeStamp,
      DateTime.now().millisecondsSinceEpoch,
    );
    await GStorage.localCache.put(LocalCacheKey.mixinKey, 'test-key');
    Request();
    mockSearch = InterceptorsWrapper(
      onRequest: (options, handler) {
        calls.update(options.path, (count) => count + 1, ifAbsent: () => 1);
        handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: {'code': 0, 'data': _response(options)},
          ),
        );
      },
    );
    Request.dio.interceptors.add(mockSearch);
  });
  tearDownAll(() => Request.dio.interceptors.remove(mockSearch));
  setUp(calls.clear);
  tearDown(Get.reset);

  Future<void> openSearch(
    WidgetTester tester, {
    double scale = 1,
    bool direct = false,
    bool waitForResults = true,
    Brightness brightness = Brightness.dark,
  }) async {
    tester.view.devicePixelRatio = 2.875;
    tester.view.physicalSize = direct ? _double : _single;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GetMaterialApp(
        theme: HarmonyTheme.apply(
          ThemeData(brightness: brightness),
          immersive: true,
        ),
        defaultTransition: Transition.noTransition,
        home: const Scaffold(body: Text('首页')),
        getPages: [
          GetPage(name: '/search', page: SearchPage.new),
          GetPage(name: '/searchResult', page: SearchResultPage.new),
          GetPage(
            name: '/searchTrending',
            page: () => const Scaffold(body: Text('榜单已打开')),
          ),
        ],
        builder: FlutterSmartDialog.init(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 28),
              viewPadding: const EdgeInsets.only(top: 28, bottom: 16),
              textScaler: TextScaler.linear(scale),
            ),
            child: child!,
          ),
        ),
      ),
    );
    if (direct) {
      Get.toNamed<void>('/searchResult', parameters: {'keyword': _query});
      if (waitForResults) {
        await tester.pumpAndSettle();
      } else {
        await tester.pump();
        await tester.pump();
      }
      return;
    }
    Get.toNamed<void>('/search', parameters: {'text': _query});
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('搜索'));
    await tester.pumpAndSettle();
  }

  testWidgets('search loader keeps its header and list pagination stable', (
    tester,
  ) async {
    final pending = _holdResultRequests();
    await openSearch(tester, direct: true, waitForResults: false);
    final spinner = find.byType(HarmonyLoadingIndicator);
    final rows = find.byType(VideoCardH);
    final sort = find.text('默认排序');
    final tabs = find.byType(TabBar);
    final sortPosition = tester.getTopLeft(sort);
    final tabsPosition = tester.getTopLeft(tabs);
    final sidebar = find.text('bilibili热搜');
    expect(sidebar, findsOneWidget);
    await _waitForResultRequest(tester, pending, '$_query:1');
    expect(pending.keys, ['$_query:1']);
    expect(spinner, findsOneWidget);
    expect(rows, findsNothing);
    expect(tester.getCenter(spinner).dy, greaterThan(sortPosition.dy + 32));

    _answer(pending.remove('$_query:1')!);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(spinner, findsOneWidget);
    expect(rows, findsNothing);
    await tester.pump(const Duration(milliseconds: 70));
    expect(spinner, findsNothing);
    expect(rows, findsWidgets);
    final fade = find.ancestor(
      of: rows.first,
      matching: find.byType(SliverOpacity),
    );
    expect(tester.widget<SliverOpacity>(fade).opacity, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(sort), sortPosition);
    expect(tester.getTopLeft(tabs), tabsPosition);
    expect(sidebar, findsOneWidget);

    final panel = tester.widget<SearchAllPanel>(find.byType(SearchAllPanel));
    final controller = Get.find<SearchAllController>(
      tag: SearchType.all.name + panel.tag,
    );
    final page = controller.onLoadMore();
    await _waitForResultRequest(tester, pending, '$_query:2');
    expect(pending.keys, ['$_query:2']);
    expect(spinner, findsNothing);
    final firstRect = tester.getRect(rows.first);
    _answer(pending.remove('$_query:2')!);
    await tester.pumpAndSettle();
    await page;
    expect(spinner, findsNothing);
    expect(tester.getRect(rows.first), firstRect);
    expect(tester.widget<SliverOpacity>(fade).opacity, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'an old keyword cannot replace the active error and empty retry',
    (
      tester,
    ) async {
      final pending = _holdResultRequests();
      await openSearch(tester, direct: true, waitForResults: false);
      const latest = '新的结果词';
      Get.toNamed<void>(
        '/searchResult',
        parameters: {'keyword': latest},
        preventDuplicates: false,
      );
      await tester.pump();
      await tester.pump();
      await _waitForResultRequest(tester, pending, '$_query:1');
      await _waitForResultRequest(tester, pending, '$latest:1');
      final active = find.ancestor(
        of: find.text(latest),
        matching: find.byType(SearchResultPage),
      );
      final spinner = find.descendant(
        of: active,
        matching: find.byType(HarmonyLoadingIndicator),
      );
      expect(spinner, findsOneWidget);
      _answer(pending.remove('$latest:1')!, error: '网络故障');
      await tester.pumpAndSettle();
      expect(find.text('网络故障', findRichText: true), findsOneWidget);
      _answer(pending.remove('$_query:1')!);
      await tester.pumpAndSettle();
      expect(find.text(latest), findsOneWidget);
      expect(find.byType(VideoCardH), findsNothing);
      await tester.tap(find.text('点击重试'));
      await tester.pump();
      expect(spinner, findsOneWidget);
      await _waitForResultRequest(tester, pending, '$latest:1');
      _answer(pending.remove('$latest:1')!, empty: true);
      await tester.pumpAndSettle();
      expect(spinner, findsNothing);
      expect(find.text('没有数据', findRichText: true), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets('search filter uses shared immersive material in $brightness', (
      tester,
    ) async {
      await openSearch(tester, direct: true, brightness: brightness);
      final defaultSort = find.text('默认排序');
      final morePlays = find.text('播放多');
      final theme = Theme.of(tester.element(defaultSort));
      expect(
        tester
            .widget<SliverFloatingHeaderWidget>(
              find.byType(SliverFloatingHeaderWidget),
            )
            .backgroundColor,
        theme.scaffoldBackgroundColor,
      );
      expect(
        tester.widget<Text>(defaultSort).style?.color,
        theme.colorScheme.primary,
      );
      expect(
        tester.widget<Text>(morePlays).style?.color,
        theme.colorScheme.onSurfaceVariant,
      );
      await tester.tap(find.byTooltip('筛选'));
      await tester.pumpAndSettle();
      final panel = find.byType(BottomPanel);
      final surface = find.descendant(
        of: panel,
        matching: find.byType(ImmersiveSurface),
      );
      expect(panel, findsOneWidget);
      expect(tester.widget<ImmersiveSurface>(surface).blurBackground, isTrue);
      expect(tester.widget<ImmersiveSurface>(surface).allowMovement, isFalse);
      expect(
        find.descendant(of: panel, matching: find.byType(BackdropFilter)),
        findsOneWidget,
      );
      expect(find.text('发布时间'), findsOneWidget);
      await tester.tap(find.text('最近一天'));
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      expect(calls[Api.searchByType], 1);
      expect(find.byType(VideoCardH), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('slow search suggestions cannot replace newer or cleared input', (
    tester,
  ) async {
    await GStorage.setting.put(SettingBoxKey.searchSuggestion, true);
    addTearDown(
      () => GStorage.setting.put(SettingBoxKey.searchSuggestion, false),
    );
    final pending = <String, (RequestOptions, RequestInterceptorHandler)>{};
    final responses = InterceptorsWrapper(
      onRequest: (request, handler) {
        if (request.path == Api.searchSuggest) {
          pending[request.queryParameters['term'] as String] = (
            request,
            handler,
          );
        } else {
          handler.next(request);
        }
      },
    );
    Request.dio.interceptors.insert(0, responses);
    addTearDown(() => Request.dio.interceptors.remove(responses));

    void answer(String term) {
      final (request, handler) = pending.remove(term)!;
      handler.resolve(
        Response(
          requestOptions: request,
          statusCode: 200,
          data: {
            'code': 0,
            'data': {
              'result': {
                'tag': [
                  {'term': term, 'name': '$term 建议'},
                ],
              },
            },
          },
        ),
      );
    }

    await tester.pumpWidget(
      GetMaterialApp(
        theme: HarmonyTheme.apply(ThemeData()),
        home: const Scaffold(body: Text('首页')),
        getPages: [GetPage(name: '/search', page: SearchPage.new)],
      ),
    );
    Get.toNamed<void>('/search');
    await tester.pumpAndSettle();
    final input = find.byType(TextField);

    Future<void> type(String term) async {
      await tester.enterText(input, term);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      expect(pending.containsKey(term), isTrue);
    }

    await type('旧词');
    await type('新词');
    answer('新词');
    await tester.pumpAndSettle();
    expect(find.text('新词 建议', findRichText: true), findsOneWidget);
    answer('旧词');
    await tester.pumpAndSettle();
    expect(find.text('旧词 建议', findRichText: true), findsNothing);
    expect(find.text('新词 建议', findRichText: true), findsOneWidget);

    await type('将清空');
    await tester.tap(find.byTooltip('清空'));
    await tester.pumpAndSettle();
    answer('将清空');
    await tester.pumpAndSettle();
    await tester.enterText(input, '再次输入');
    await tester.pump();
    expect(find.text('将清空 建议', findRichText: true), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 250));
  });

  testWidgets('search result rows and sidebar follow physical fold sizes', (
    tester,
  ) async {
    await openSearch(tester);
    for (final size in [_single, _double, _triple, _single.flipped, _single]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      final split = size == _double || size == _triple;
      final route = find.byType(SearchResultPage);
      final heading = find.descendant(
        of: route,
        matching: find.text('bilibili热搜'),
      );
      final cards = find.byType(VideoCardH);
      expect(heading, split ? findsOneWidget : findsNothing);
      expect(
        find.descendant(of: route, matching: find.text('搜索发现')),
        split ? findsOneWidget : findsNothing,
      );
      expect(cards.evaluate().length, greaterThanOrEqualTo(2), reason: '$size');
      final first = tester.getRect(cards.at(0));
      final second = tester.getRect(cards.at(1));
      expect(second.left, first.left);
      expect(second.top, closeTo(first.bottom, .01));
      final cover = tester.getRect(
        find.descendant(
          of: cards.first,
          matching: find.byType(NetworkImgLayer),
        ),
      );
      expect(cover.width, closeTo(172, .01));
      expect(cover.width / cover.height, closeTo(16 / 9, .001));
      final query = tester.getRect(
        find.descendant(of: route, matching: find.text(_query)),
      );
      expect(query.top, greaterThanOrEqualTo(28));
      if (split) {
        final divider = tester.getRect(
          find
              .descendant(of: route, matching: find.byType(VerticalDivider))
              .last,
        );
        expect(divider.width, 1);
        expect(divider.top, 28);
        expect(first.right, divider.left);
        expect(tester.getTopLeft(heading).dx, greaterThan(divider.right));
        expect(tester.getCenter(heading).dy, closeTo(query.center.dy, 12));
        if (size == _triple) {
          expect(first.left, closeTo((size.width / 2.875 - 960) / 2, .01));
          expect(first.width, closeTo(719, .01));
        } else {
          expect(first.width, closeTo(size.width / 2.875 * 2 / 3 - 1, .01));
        }
      }
      expect(tester.takeException(), isNull, reason: '$size');
    }
    expect(
      calls[Api.searchAll],
      1,
      reason: 'folding keeps the results mounted',
    );
    expect(calls[Api.searchTrending], 1);
    expect(calls[Api.searchRecommend], 1);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'large text fits and the keyword pane scrolls and searches independently',
    (
      tester,
    ) async {
      await openSearch(tester, scale: 1.3);
      for (final size in [_single, _double, _triple, const Size(860, 2232)]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        final first = find.byType(VideoCardH).first;
        final cover = find.descendant(
          of: first,
          matching: find.byType(NetworkImgLayer),
        );
        expect(
          tester.getRect(cover).right,
          lessThan(tester.getRect(first).right - 85),
        );
        if (size.width == 860) {
          expect(tester.getSize(cover).width, lessThan(172));
        }
        expect(tester.takeException(), isNull, reason: '$size / 1.3');
      }
      tester.view.physicalSize = _double;
      await tester.pumpAndSettle();
      await tester.tap(find.text('直播间'));
      await tester.pumpAndSettle();
      expect(
        find.byType(HttpError),
        findsNothing,
        reason: tester
            .widgetList<HttpError>(find.byType(HttpError))
            .map((e) => e.errMsg)
            .join('\n'),
      );
      final live = find.byType(LiveItem).first;
      final cover = find.descendant(
        of: live,
        matching: find.byType(NetworkImgLayer),
      );
      expect(tester.getSize(cover).width, closeTo(172, .01));
      expect(find.textContaining('围观 ·'), findsWidgets);
      expect(tester.takeException(), isNull);

      final sidebar = find
          .ancestor(
            of: find.text('bilibili热搜'),
            matching: find.byType(Scrollable),
          )
          .first;
      final results = find
          .ancestor(of: live, matching: find.byType(Scrollable))
          .first;
      final sidebarPosition = tester.state<ScrollableState>(sidebar).position;
      final resultsPosition = tester.state<ScrollableState>(results).position;
      await tester.drag(sidebar, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(sidebarPosition.pixels, greaterThan(0));
      expect(resultsPosition.pixels, 0);
      await tester.drag(results, const Offset(0, -230));
      await tester.pumpAndSettle();
      expect(resultsPosition.pixels, greaterThan(0));
      expect(sidebarPosition.pixels, greaterThan(0));

      sidebarPosition.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(find.text('完整榜单'));
      await tester.pumpAndSettle();
      expect(find.text('榜单已打开'), findsOneWidget);
      Get.back<void>();
      await tester.pumpAndSettle();
      final keywords = Get.find<BaseSearchController>();
      await tester.tap(find.text('热门搜索词0'));
      await tester.pumpAndSettle();
      expect(Get.parameters['keyword'], '热门搜索词0');
      expect(Get.find<BaseSearchController>(), same(keywords));
      expect(calls[Api.searchTrending], 1);
      expect(calls[Api.searchRecommend], 1);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('editing a direct wide search preserves its keyword session', (
    tester,
  ) async {
    await openSearch(tester, direct: true);
    final keywords = Get.find<BaseSearchController>();
    expect(find.text('bilibili热搜'), findsOneWidget);
    await tester.tap(find.text(_query));
    await tester.pumpAndSettle();
    expect(find.byType(SearchPage), findsOneWidget);
    await tester.enterText(find.byType(TextField), '另一条搜索');
    await tester.tap(find.byTooltip('搜索'));
    await tester.pumpAndSettle();
    expect(Get.parameters['keyword'], '另一条搜索');
    expect(Get.find<BaseSearchController>(), same(keywords));
    expect(calls[Api.searchTrending], 1);
    expect(calls[Api.searchRecommend], 1);
    Get.back<void>();
    await tester.pumpAndSettle();
    expect(find.byType(SearchPage), findsOneWidget);
    Get.back<void>();
    await tester.pumpAndSettle();
    expect(find.byType(SearchResultPage), findsOneWidget);
    expect(find.text(_query), findsOneWidget);
    Get.back<void>();
    await tester.pumpAndSettle();
    expect(find.text('首页'), findsOneWidget);
    expect(Get.isRegistered<BaseSearchController>(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all search categories stay in one column with long text', (
    tester,
  ) async {
    await openSearch(tester, direct: true, scale: 1.3);
    final controller = tester.widget<TabBar>(find.byType(TabBar)).controller!;
    for (final (type, card) in [
      (SearchType.video, VideoCardH),
      (SearchType.media_bangumi, SearchPgcItem),
      (SearchType.media_ft, SearchPgcItem),
      (SearchType.live_room, LiveItem),
      (SearchType.bili_user, SearchUserItem),
      (SearchType.article, SearchArticleItem),
    ]) {
      controller.animateTo(type.index);
      await tester.pumpAndSettle();
      for (final size in [_double, _single, _triple]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        final rows = find.byType(card).hitTestable();
        expect(
          rows.evaluate().length,
          greaterThanOrEqualTo(2),
          reason:
              '$type / $size: ${tester.widgetList<HttpError>(find.byType(HttpError)).map((e) => e.errMsg).join('\n')}',
        );
        final first = tester.getRect(rows.at(0));
        final second = tester.getRect(rows.at(1));
        expect(second.left, first.left);
        expect(second.top, closeTo(first.bottom, .01));
        expect(tester.takeException(), isNull, reason: '$type / $size');
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}

typedef _PendingResult = (RequestOptions, RequestInterceptorHandler);

Map<String, _PendingResult> _holdResultRequests() {
  final requests = <String, _PendingResult>{};
  final interceptor = InterceptorsWrapper(
    onRequest: (options, handler) {
      if (options.path == Api.searchAll || options.path == Api.searchByType) {
        final query = options.queryParameters;
        requests['${query['keyword']}:${query['page']}'] = (options, handler);
      } else {
        handler.next(options);
      }
    },
  );
  Request.dio.interceptors.insert(0, interceptor);
  addTearDown(() => Request.dio.interceptors.remove(interceptor));
  return requests;
}

Future<void> _waitForResultRequest(
  WidgetTester tester,
  Map<String, _PendingResult> pending,
  String key,
) async {
  for (var frame = 0; frame < 20 && !pending.containsKey(key); frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(pending, contains(key));
}

void _answer(_PendingResult result, {String? error, bool empty = false}) {
  final (request, handler) = result;
  handler.resolve(
    Response(
      requestOptions: request,
      statusCode: 200,
      data: error != null
          ? {'code': -1, 'message': error}
          : {
              'code': 0,
              'data': empty
                  ? {'numResults': 0, 'result': []}
                  : _response(request),
            },
    ),
  );
}

Map<String, dynamic> _response(
  RequestOptions options,
) => switch (options.path) {
  Api.searchTrending => {
    'list': [
      for (var i = 0; i < 10; i++) {'keyword': '热门搜索词$i'},
    ],
  },
  Api.searchRecommend => {
    'list': [
      for (var i = 0; i < 16; i++) {'keyword': '发现搜索词$i'},
    ],
  },
  Api.searchAll => {
    'numResults': 20,
    'result': [
      {
        'result_type': 'video',
        'data': _videoFixtures(),
      },
    ],
  },
  Api.searchByType when options.queryParameters['search_type'] == 'live_room' =>
    {
      'numResults': 20,
      'result': [
        for (var i = 0; i < 20; i++)
          {
            'roomid': 20000 + i,
            'title': '$_liveTitle $i',
            'uname': _author,
            'online': 10980,
            'cate_name': '游戏赛事',
          },
      ],
    },
  Api.searchByType when options.queryParameters['search_type'] == 'video' => {
    'numResults': 20,
    'result': _videoFixtures(),
  },
  Api.searchByType
      when const {
        'media_bangumi',
        'media_ft',
      }.contains(options.queryParameters['search_type']) =>
    {
      'numResults': 8,
      'result': [
        for (var i = 0; i < 8; i++)
          {
            'season_id': i + 1,
            'title': '番剧 $i $_videoTitle$_videoTitle',
            'areas': '地区 $_videoTitle',
            'styles': '风格 $_videoTitle',
            'index_show': '全18话',
          },
      ],
    },
  Api.searchByType when options.queryParameters['search_type'] == 'bili_user' =>
    {
      'numResults': 8,
      'result': [
        for (var i = 0; i < 8; i++)
          {
            'mid': i + 1,
            'uname': '用户 $i $_author$_author',
            'level': 1,
            'fans': 100000000,
            'videos': 200000000,
          },
      ],
    },
  Api.searchByType when options.queryParameters['search_type'] == 'article' => {
    'numResults': 8,
    'result': [
      for (var i = 0; i < 8; i++)
        {
          'id': i + 1,
          'title': '专栏 $i $_videoTitle$_videoTitle',
          'pub_time': 1740000000,
          'image_urls': [''],
          'view': 2000000000,
          'reply': 2000000000,
        },
    ],
  },
  _ => {'numResults': 0, 'result': []},
};

List<Map<String, dynamic>> _videoFixtures() => [
  for (var i = 0; i < 20; i++)
    {
      'aid': 20000 + i,
      'title': '$_videoTitle $i',
      'author': _author,
      'play': 1188000,
      'pubdate': 1740000000,
      'duration': '11:00',
    },
];
