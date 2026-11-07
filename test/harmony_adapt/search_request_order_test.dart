import 'dart:async';

import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/search/search_type.dart';
import 'package:PiliPlus/models/search/result.dart';
import 'package:PiliPlus/pages/search_panel/controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _Results extends SearchNumData<String> {
  _Results(List<String> values)
    : super(list: values, numResults: values.length);
}

class _Search extends SearchPanelController<_Results, String> {
  _Search() : super(keyword: '测试', searchType: SearchType.video, tag: 'race');

  final requests = <Completer<LoadingState<_Results>>>[];
  final parameters = <(int, String)>[];

  @override
  Future<LoadingState<_Results>> customGetData() {
    parameters.add((page, order));
    final request = Completer<LoadingState<_Results>>();
    requests.add(request);
    return request.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'changing sort during pagination starts a fresh search immediately',
    () async {
      final controller = _Search();
      addTearDown(controller.scrollController.dispose);
      controller.loadingState.value = Success(['原结果']);
      controller.page = 2;
      final pagination = controller.onLoadMore();
      controller.order = 'click';
      final sorted = controller.onReload();
      expect(controller.parameters, [(2, ''), (1, 'click')]);
      expect(controller.loadingState.value, isA<Loading>());

      controller.requests[0].complete(Success(_Results(['旧分页'])));
      await pagination;
      expect(controller.isLoading, isTrue);
      expect(controller.loadingState.value, isA<Loading>());
      controller.requests[1].complete(Success(_Results(['新排序'])));
      await sorted;
      expect(controller.loadingState.value.data, ['新排序']);
      expect(controller.page, 2);
      expect(controller.isLoading, isFalse);
      expect(controller.loadingMore.value, isFalse);
    },
  );

  test('late first-search response cannot overwrite a newer filter', () async {
    final controller = _Search();
    addTearDown(controller.scrollController.dispose);
    final initial = controller.queryData();
    controller.order = 'pubdate';
    final filtered = controller.onReload();
    controller.requests[1].complete(Success(_Results(['最新发布'])));
    await filtered;
    controller.requests[0].complete(Success(_Results(['默认排序'])));
    await initial;
    expect(controller.loadingState.value.data, ['最新发布']);
    expect(controller.page, 2);
    expect(controller.isLoading, isFalse);
  });
}
