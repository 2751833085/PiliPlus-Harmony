import 'dart:async';

import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart'
    show MainListReply, ReplyControl, ReplyInfo, SubjectControl;
import 'package:PiliPlus/http/api.dart';
import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/pages/common/reply_controller.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:dio/dio.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/memory_box.dart';

class _Replies extends ReplyController<MainListReply> {
  MainListReply next = MainListReply();

  @override
  int get sourceId => 1;

  @override
  Future<LoadingState<MainListReply>> customGetData() async => Success(next);

  @override
  List<ReplyInfo> getDataList(MainListReply response) => response.replies;
}

ReplyInfo _reply(
  int id, {
  bool pinned = false,
  List<ReplyInfo> children = const [],
}) => ReplyInfo(
  id: Int64(id),
  replyControl: pinned ? ReplyControl(isUpTop: true) : null,
  count: Int64(children.length),
  replies: children,
);

void main() {
  setUpAll(() {
    GStorage.setting = MemoryBox();
    GStorage.localCache = MemoryBox();
  });

  testWidgets('pin response locates the reply in the refreshed order', (
    tester,
  ) async {
    Request();
    final pending = <(RequestOptions, RequestInterceptorHandler)>[];
    final mock = InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path == Api.replyTop) {
          pending.add((options, handler));
        } else {
          handler.reject(DioException(requestOptions: options));
        }
      },
    );
    Request.dio.interceptors.insert(0, mock);
    addTearDown(() => Request.dio.interceptors.remove(mock));
    await tester.pumpWidget(
      MaterialApp(
        builder: FlutterSmartDialog.init(),
        home: const Scaffold(),
      ),
    );
    final controller = _Replies()..onInit();
    addTearDown(controller.onDelete.call);
    final selected = _reply(10);
    controller.loadingState.value = Success([_reply(7), selected, _reply(9)]);
    final pin = controller.onToggleTop(selected, 1, 1);
    await tester.pump(const Duration(milliseconds: 1));
    final (request, _) = pending.single;
    expect(request.data['rpid'], selected.id);

    final refreshedTarget = _reply(10);
    final previouslyPinned = _reply(7, pinned: true);
    controller.next = MainListReply(
      upTop: previouslyPinned,
      replies: [_reply(9), refreshedTarget],
      subjectControl: SubjectControl(count: Int64(3)),
    );
    await controller.onRefresh();
    void resolvePin() {
      final (request, handler) = pending.last;
      handler.resolve(
        Response(
          requestOptions: request,
          statusCode: 200,
          data: {'code': 0},
        ),
      );
    }

    resolvePin();
    await tester.pump(const Duration(milliseconds: 1));
    await pin;
    expect(controller.loadingState.value.data!.map((item) => item.id.toInt()), [
      10,
      7,
      9,
    ]);
    expect(refreshedTarget.replyControl.isUpTop, isTrue);
    expect(previouslyPinned.replyControl.isUpTop, isFalse);
    expect(controller.hasUpTop, isTrue);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 150));

    final unpin = controller.onToggleTop(refreshedTarget, 1, 1);
    await tester.pump(const Duration(milliseconds: 1));
    controller.loadingState.value = LoadingState.loading();
    resolvePin();
    await tester.pump(const Duration(milliseconds: 1));
    await unpin;
    expect(controller.loadingState.value, isA<Loading>());
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpWidget(const SizedBox());
  });

  test('delete completion finds both refreshed root and child by id', () async {
    final controller = _Replies()..onInit();
    addTearDown(controller.onDelete.call);
    final child = _reply(11);
    final selected = _reply(10, children: [child]);
    controller.loadingState.value = Success([selected, _reply(20)]);
    final pending = Completer<void>();
    final delete = pending.future.then(
      (_) => controller.onRemove(selected, child),
    );

    final refreshedTarget = _reply(10, children: [_reply(12), _reply(11)]);
    controller.next = MainListReply(
      replies: [_reply(20), refreshedTarget],
      subjectControl: SubjectControl(count: Int64(4)),
    );
    await controller.onRefresh();
    pending.complete();
    await delete;
    expect(refreshedTarget.replies.single.id, Int64(12));
    expect(refreshedTarget.count, Int64(1));
    expect(controller.count.value, 3);

    controller.onRemove(selected, child);
    expect(controller.count.value, 3);
    controller.onRemove(selected, null);
    expect(controller.loadingState.value.data!.single.id, Int64(20));
    expect(controller.count.value, 2);
    controller.loadingState.value = LoadingState.loading();
    controller.onRemove(selected, null);
    expect(controller.loadingState.value, isA<Loading>());
    expect(controller.count.value, 2);
  });
}
