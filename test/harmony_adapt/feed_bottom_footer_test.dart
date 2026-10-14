import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/harmony_adapt/widgets/feed_bottom_footer.dart';
import 'package:PiliPlus/harmony_adapt/widgets/native_navigation_spacer.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/pages/common/common_list_controller.dart';

class _Feed extends CommonListController<List<int>, int> {
  final requests = <Completer<LoadingState<List<int>>>>[];
  @override
  Future<LoadingState<List<int>>> customGetData() {
    final task = Completer<LoadingState<List<int>>>();
    requests.add(task);
    return task.future;
  }
}

void main() {
  test(
    'pagination spinner tracks pending next-page work, never initial load or stale work',
    () async {
      final feed = _Feed();
      final initial = feed.queryData();
      expect(feed.loadingMore.value, false);
      feed.requests[0].complete(const Success([1]));
      await initial;
      final next = feed.onLoadMore();
      expect(feed.loadingMore.value, true);
      await feed.onLoadMore(); // duplicate must not clear the pending indicator
      expect(feed.requests.length, 2);
      expect(feed.loadingMore.value, true);
      feed.invalidateRequests();
      final fresh = feed.onRefresh();
      expect(feed.loadingMore.value, false);
      feed.requests[2].complete(Success([3]));
      await fresh;
      final newNext = feed.onLoadMore();
      expect(feed.loadingMore.value, true);
      feed.requests[1].complete(const Success([2]));
      await next;
      expect(feed.loadingMore.value, true);
      feed.requests[3].complete(const Success([4]));
      await newNext;
      expect(feed.loadingMore.value, false);
      expect(feed.loadingState.value.data, [3, 4]);
      feed.scrollController.dispose();
    },
  );

  test(
    'empty, failed and thrown pagination all release the loading indicator',
    () async {
      for (final response in <LoadingState<List<int>>?>[
        const Success<List<int>>([]),
        const Error('offline'),
        null,
      ]) {
        final feed = _Feed();
        final pending = feed.onLoadMore();
        expect(feed.loadingMore.value, true);
        if (response == null) {
          final check = expectLater(pending, throwsStateError);
          feed.requests.single.completeError(StateError('offline'));
          await check;
        } else {
          feed.requests.single.complete(response);
          await pending;
        }
        expect(feed.isLoading, false);
        expect(feed.loadingMore.value, false);
        feed.scrollController.dispose();
      }
    },
  );

  testWidgets(
    'last video and footer scroll above native navigation at real fold density',
    (tester) async {
      tester.view.devicePixelRatio = 2.875;
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      });
      for (final width in [390.0, 740.0, 1108.0]) {
        tester.view.physicalSize = Size(width, 800) * 2.875;
        final loading = ValueNotifier<bool>(true);
        final extent = ValueNotifier<double>(76);
        final scroll = ScrollController();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              extendBody: true,
              bottomNavigationBar: NativeNavigationSpacer(
                extent: extent,
                scale: 1,
                fallback: 76,
              ),
              body: CustomScrollView(
                controller: scroll,
                slivers: [
                  SliverList.list(
                    children: List.generate(
                      8,
                      (i) => SizedBox(
                        height: 150,
                        key: ValueKey('video-$i'),
                        child: Text('video $i'),
                      ),
                    ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: loading,
                    builder: (_, value, __) => FeedBottomFooter(loading: value),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));
        scroll.jumpTo(scroll.position.maxScrollExtent);
        await tester.pump(const Duration(milliseconds: 200));
        final barTop = tester
            .getTopLeft(find.byType(NativeNavigationSpacer))
            .dy;
        expect(
          tester.getBottomLeft(find.byKey(const ValueKey('video-7'))).dy,
          lessThan(barTop),
        );
        expect(tester.getBottomLeft(find.text('正在加载…')).dy, lessThan(barTop));
        final end = scroll.position.maxScrollExtent;
        loading.value = false;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('正在加载…'), findsNothing);
        expect(
          scroll.position.maxScrollExtent,
          end,
        ); // spinner exit cannot snap the list
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        scroll.dispose();
        loading.dispose();
        extent.dispose();
      }
    },
  );
}
