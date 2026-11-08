import 'package:PiliPlus/http/api.dart';
import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/models_new/sub/sub/list.dart';
import 'package:PiliPlus/pages/subscription/widgets/item.dart';
import 'package:PiliPlus/pages/subscription_detail/view.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers/memory_box.dart';

void main() {
  setUpAll(() {
    GStorage.setting = MemoryBox();
    Request();
  });
  tearDown(Get.reset);

  testWidgets('an expired subscription with missing metadata stays visible', (
    tester,
  ) async {
    final expired = SubItemModel.fromJson({'id': 1, 'state': 1, 'type': 21});
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 340,
              height: 110,
              child: SubItem(item: expired, cancelSub: () {}),
            ),
          ),
        ),
      ),
    );
    expect(find.text('已失效的合集'), findsOneWidget);
    expect(find.text('UP主: 未知'), findsOneWidget);
    expect(find.text('视频数量未知'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a live subscription with unnamed owner opens its detail', (
    tester,
  ) async {
    final item = SubItemModel.fromJson({
      'id': 2,
      'type': 21,
      'upper': <String, Object>{},
    });
    final requested = <String>[];
    final stub = InterceptorsWrapper(
      onRequest: (options, handler) {
        requested.add(options.path);
        handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'code': 0,
              'data': {
                'info': {'id': 2, 'type': 21},
                'medias': [],
              },
            },
          ),
        );
      },
    );
    Request.dio.interceptors.insert(0, stub);
    addTearDown(() => Request.dio.interceptors.remove(stub));
    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 340,
              height: 110,
              child: SubItem(item: item, cancelSub: () {}),
            ),
          ),
        ),
        getPages: [GetPage(name: '/subDetail', page: SubDetailPage.new)],
      ),
    );
    expect(find.text('UP主: 未知'), findsOneWidget);
    await tester.tap(find.text('未命名订阅'));
    await tester.pumpAndSettle();
    expect(requested, [Api.favSeasonList]);
    expect(find.byType(SubDetailPage), findsOneWidget);
    expect(find.text('未命名订阅'), findsWidgets);
    expect(find.text('未知UP主'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
