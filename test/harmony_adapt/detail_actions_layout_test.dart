import 'package:PiliPlus/common/widgets/scaffold/mini_scaffold.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/common/widgets/sliver/sliver_floating_header.dart';
import 'package:PiliPlus/common/widgets/sliver/sliver_pinned_header.dart';
import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart';
import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/reply/reply_sort_type.dart';
import 'package:PiliPlus/models/dynamics/result.dart';
import 'package:PiliPlus/models_new/article/article_view/data.dart';
import 'package:PiliPlus/pages/article/controller.dart';
import 'package:PiliPlus/pages/article/view.dart';
import 'package:PiliPlus/pages/dynamics_detail/controller.dart';
import 'package:PiliPlus/pages/dynamics_detail/view.dart';
import 'package:PiliPlus/pages/video/reply/widgets/reply_item_grpc.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'helpers/memory_box.dart';

const _single = Size(1008, 2232);
const _double = Size(2048, 2232);
const _triple = Size(3184, 2232);
const _firstCount = '9999.9万';
const _lastCount = '9876.5万';
const _replyCount = 30;

ModuleStatModel _stats() => ModuleStatModel(
  comment: DynamicStat(count: _replyCount),
  forward: DynamicStat(count: 99999000),
  like: DynamicStat(count: 98765000),
  favorite: DynamicStat(count: 12345600),
);

List<ReplyInfo> _replies() => [
  for (var i = 1; i <= _replyCount; i++)
    ReplyInfo(
      id: Int64(i),
      oid: Int64(123),
      mid: Int64(2),
      member: Member(mid: Int64(2), name: '测试评论作者'),
      content: Content(message: '测试评论 $i'),
    ),
];

class _ArticleController extends ArticleController {
  @override
  void onInit() {
    id = '123';
    type = 'read';
    url = 'https://example.invalid/article';
    commentType = 12;
    commentId = 123;
    summary.title = '测试文章标题';
    articleData = ArticleViewData(
      content: [for (var i = 1; i <= 75; i++) '<p>文章正文段落 $i</p>'].join(),
    );
    stats.value = _stats();
    sortType = ReplySortType.hot.obs;
    loadingState.value = Success(_replies());
    count.value = _replyCount;
    isEnd = true;
    isLoaded.value = true;
  }
}

class _DynamicController extends DynamicDetailController {
  _DynamicController(this.fixture);
  final DynamicItemModel fixture;

  @override
  void onInit() {
    dynItem = fixture;
    oid = 123;
    replyType = 11;
    sortType = ReplySortType.hot.obs;
    loadingState.value = Success(_replies());
    count.value = _replyCount;
    isEnd = true;
  }
}

void main() {
  setUpAll(() {
    GStorage.setting = MemoryBox();
    GStorage.localCache = MemoryBox();
  });
  tearDown(Get.reset);

  Future<void> open(WidgetTester tester, {required bool article}) async {
    tester.view.devicePixelRatio = 2.875;
    tester.view.physicalSize = _triple;
    addTearDown(tester.view.reset);
    final item = DynamicItemModel.fromJson({
      'id_str': '123',
      'type': 'DYNAMIC_TYPE_WORD',
      'modules': {
        'module_author': {'mid': 3, 'name': '测试动态作者'},
        'module_dynamic': {
          'desc': {'text': '测试动态正文'},
        },
      },
    });
    item.modules.moduleStat = _stats();
    await tester.pumpWidget(
      GetMaterialApp(
        theme: HarmonyTheme.apply(
          article ? ThemeData.light() : ThemeData.dark(),
          immersive: true,
        ),
        defaultTransition: Transition.noTransition,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(1.3),
            viewPadding: const EdgeInsets.only(top: 28, bottom: 20),
            padding: const EdgeInsets.only(top: 28, bottom: 20),
          ),
          child: child!,
        ),
        home: const Scaffold(body: Text('测试首页')),
        getPages: [
          GetPage(
            name: '/articlePage',
            page: ArticlePage.new,
            binding: BindingsBuilder(() {
              Get.put<ArticleController>(_ArticleController(), tag: 'read123');
            }),
          ),
          GetPage(
            name: '/dynamicDetail',
            page: DynamicDetailPage.new,
            binding: BindingsBuilder(() {
              Get.put<DynamicDetailController>(
                _DynamicController(item),
                tag: '123',
              );
            }),
          ),
        ],
      ),
    );
    if (article) {
      Get.toNamed<void>(
        '/articlePage',
        parameters: {'type': 'read', 'id': '123'},
      );
    } else {
      Get.toNamed<void>('/dynamicDetail', arguments: {'item': item});
    }
    await tester.pumpAndSettle();
  }

  Finder action(String label) => find.widgetWithText(TextButton, label);

  void checkActionTargets(WidgetTester tester, bool split) {
    final reply = find.byTooltip('评论');
    final actions = [_firstCount, '分享', _lastCount].map(action);
    final outer = tester.widget<SimpleScaffold>(
      find.byType(SimpleScaffold).first,
    );
    expect(outer.fab != null, !split);
    final theme = Theme.of(tester.element(action(_firstCount)));
    expect(outer.backgroundColor, theme.scaffoldBackgroundColor);
    expect(find.byType(BackdropFilter), findsNothing);
    for (final target in actions) {
      expect(target, findsOneWidget);
      expect(tester.getSize(target).height, 48);
    }
    if (split) {
      final pane = find.byType(MiniScaffold);
      expect(pane, findsOneWidget);
      final region = tester.getRect(pane);
      expect(tester.getRect(reply).left, greaterThan(region.left));
      expect(tester.getRect(reply).bottom, lessThan(region.bottom - 48));
      expect(
        find.descendant(of: pane, matching: action('分享')),
        findsOneWidget,
      );
    } else {
      expect(find.byType(MiniScaffold), findsNothing);
      expect(tester.getRect(action(_firstCount)).left, 0);
    }
  }

  testWidgets(
    'article actions stay in their pane through native folds and wide double',
    (tester) async {
      await open(tester, article: true);
      for (final size in [
        _triple,
        _double,
        _single,
        _double.flipped,
        _triple,
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        checkActionTargets(tester, size.width > size.height);
        if (size.width > size.height) {
          final sort = find.text('最热');
          final theme = Theme.of(tester.element(sort));
          expect(
            tester.widget<Text>(sort).style!.color,
            theme.colorScheme.onSurfaceVariant,
          );
          expect(
            tester
                .widget<SliverPinnedHeader>(find.byType(SliverPinnedHeader))
                .backgroundColor,
            theme.scaffoldBackgroundColor,
          );
        }
        if (size == _double.flipped) {
          final overflowRow = find.ancestor(
            of: action(_firstCount),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is SingleChildScrollView &&
                  widget.scrollDirection == Axis.horizontal,
            ),
          );
          expect(overflowRow, findsOneWidget);
          await tester.drag(overflowRow, const Offset(-160, 0));
          await tester.pumpAndSettle();
          expect(action(_lastCount).hitTestable(), findsOneWidget);
        }
        expect(tester.takeException(), isNull, reason: '$size');
      }
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'wide article scroll responds only to comments and leaves the last reply clear',
    (tester) async {
      await open(tester, article: true);
      final left = find.descendant(
        of: find.byType(SelectionArea),
        matching: find.byType(CustomScrollView),
      );
      final right = find.descendant(
        of: find.byType(MiniScaffold),
        matching: find.byType(CustomScrollView),
      );
      final reply = find.byTooltip('评论');
      final initial = tester.getRect(reply);
      await tester.drag(left, const Offset(0, -220));
      await tester.pumpAndSettle();
      expect(tester.getRect(reply), initial);
      await tester.drag(right, const Offset(0, -250));
      await tester.pumpAndSettle();
      expect(reply.hitTestable(), findsNothing);
      await tester.drag(right, const Offset(0, 100));
      await tester.pumpAndSettle();
      expect(reply.hitTestable(), findsOneWidget);
      final scroll = tester
          .state<ScrollableState>(
            find.descendant(of: right, matching: find.byType(Scrollable)).first,
          )
          .position;
      scroll.jumpTo(scroll.maxScrollExtent);
      await tester.pumpAndSettle();
      scroll.jumpTo(scroll.maxScrollExtent);
      await tester.pumpAndSettle();
      final last = find.byWidgetPredicate(
        (w) => w is ReplyItemGrpc && w.replyItem.id.toInt() == _replyCount,
      );
      expect(last, findsOneWidget);
      expect(
        tester.getRect(last).bottom,
        lessThanOrEqualTo(tester.getRect(reply).top),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'dynamic detail shares scoped dark actions and neutral comment sorting',
    (tester) async {
      await open(tester, article: false);
      checkActionTargets(tester, true);
      final sort = find.text('最热');
      final theme = Theme.of(tester.element(sort));
      expect(
        tester.widget<Text>(sort).style!.color,
        theme.colorScheme.onSurfaceVariant,
      );
      final floating = tester.widgetList<SliverFloatingHeaderWidget>(
        find.byType(SliverFloatingHeaderWidget),
      );
      expect(
        floating.any((w) => w.backgroundColor == theme.scaffoldBackgroundColor),
        isTrue,
      );
      tester.view.physicalSize = _single;
      await tester.pumpAndSettle();
      checkActionTargets(tester, false);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
