import 'dart:async';

import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/dynamic/dynamics_type.dart';
import 'package:PiliPlus/models/dynamics/result.dart';
import 'package:PiliPlus/pages/dynamics/controller.dart';
import 'package:PiliPlus/pages/dynamics_tab/controller.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'helpers/memory_box.dart';

class _SelectedAuthor extends GetxController implements DynamicsController {
  @override
  int hostMid = 1;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AuthorPosts extends DynamicsTabController {
  _AuthorPosts() : super(dynamicsType: DynamicsTabType.up);

  final requests = <Completer<LoadingState<DynamicsDataModel>>>[];
  final parameters = <(int, String?)>[];

  @override
  Future<LoadingState<DynamicsDataModel>> customGetData() {
    parameters.add((dynamicsController.hostMid, offset));
    final request = Completer<LoadingState<DynamicsDataModel>>();
    requests.add(request);
    return request.future;
  }
}

void main() {
  setUpAll(() => GStorage.setting = MemoryBox());
  tearDown(Get.reset);

  test(
    'changing UP creator replaces an in-flight page and its cursor',
    () async {
      final author = Get.put<DynamicsController>(_SelectedAuthor());
      final posts = _AuthorPosts()
        ..offset = 'old-page'
        ..loadingState.value = Success([
          DynamicItemModel.fromJson({'id_str': 'old-post'}),
        ]);
      addTearDown(posts.scrollController.dispose);
      final oldPage = posts.onLoadMore();

      author.hostMid = 2;
      final newPage = posts.onReload();
      expect(posts.parameters, [(1, 'old-page'), (2, null)]);

      DynamicsDataModel result(String id, String cursor) =>
          DynamicsDataModel.fromJson({
            'items': [
              {'id_str': id},
            ],
            'offset': cursor,
          });
      posts.requests.first.complete(Success(result('obsolete', 'old-cursor')));
      await oldPage;
      expect(posts.loadingState.value, isA<Loading>());
      expect(posts.isLoading, isTrue);

      posts.requests.last.complete(Success(result('current', 'new-cursor')));
      await newPage;
      expect(posts.loadingState.value.data?.single.idStr, 'current');
      expect(posts.offset, 'new-cursor');
      expect(posts.isLoading, isFalse);
    },
  );
}
