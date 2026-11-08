import 'dart:async';

import 'package:PiliPlus/grpc/bilibili/app/im/v1.pb.dart' show SessionMainReply;
import 'package:PiliPlus/grpc/bilibili/im/interfaces/v1.pb.dart'
    show MsgFeedUnreadRsp, RspSendMsg, RspSessionMsg, RspTotalUnread;
import 'package:PiliPlus/grpc/bilibili/im/type.pb.dart' show Msg, MsgType;
import 'package:PiliPlus/grpc/grpc_req.dart';
import 'package:PiliPlus/grpc/url.dart';
import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/account_type.dart';
import 'package:PiliPlus/pages/whisper/controller.dart';
import 'package:PiliPlus/pages/whisper/view.dart';
import 'package:PiliPlus/pages/whisper_detail/controller.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/accounts/account.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'helpers/memory_box.dart';

class _Account extends LoginAccount {
  _Account([this._mid = 11]) : super(DefaultCookieJar(), null, null);

  final int _mid;

  @override
  int get mid => _mid;
}

class _Conversation extends WhisperDetailController {
  final requests = <Completer<LoadingState<RspSessionMsg>>>[];

  @override
  Future<LoadingState<RspSessionMsg>> customGetData() {
    final request = Completer<LoadingState<RspSessionMsg>>();
    requests.add(request);
    return request.future;
  }
}

void main() {
  setUpAll(() {
    GStorage.setting = MemoryBox();
    GStorage.localCache = MemoryBox();
  });

  test(
    'new message refresh replaces an in-flight older history page',
    () async {
      final conversation = _Conversation();
      addTearDown(conversation.scrollController.dispose);
      conversation.msgSeqno = Int64(20);
      conversation.loadingState.value = Success([Msg(msgKey: Int64(20))]);
      final paging = conversation.onLoadMore();
      final refresh = conversation.onRefresh();
      expect(conversation.requests, hasLength(2));
      expect(conversation.msgSeqno, isNull);

      conversation.requests.first.complete(
        Success(
          RspSessionMsg(
            messages: [Msg(msgKey: Int64(19), msgType: 18, msgSource: 18)],
          ),
        ),
      );
      await paging;
      expect(conversation.isLoading, isTrue);
      expect(conversation.loadingState.value.data?.single.msgKey, Int64(20));

      conversation.requests.last.complete(
        Success(
          RspSessionMsg(
            messages: [Msg(msgKey: Int64(21), msgType: 18, msgSource: 18)],
          ),
        ),
      );
      await refresh;
      expect(conversation.loadingState.value.data?.single.msgKey, Int64(21));
    },
  );

  testWidgets(
    'message recall uses the stable key after the conversation changes',
    (
      tester,
    ) async {
      final index = AccountType.main.index;
      final previous = Accounts.accountMode[index];
      Accounts.accountMode[index] = _Account();
      addTearDown(() => Accounts.accountMode[index] = previous);
      Request();
      final requests = <(RequestOptions, RequestInterceptorHandler)>[];
      final mock = InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path.endsWith(GrpcUrl.sendMsg)) {
            requests.add((options, handler));
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
      final conversation = WhisperDetailController()..talkerId = 22;
      final target = Msg(msgKey: Int64(100));
      final other = Msg(msgKey: Int64(200));
      conversation.loadingState.value = Success([target, other]);
      final recall = conversation.sendMsg(
        message: '100',
        msgType: MsgType.EN_MSG_TYPE_DRAW_BACK,
        onClearText: () => fail('recall must not clear the draft'),
      );
      await tester.pump(const Duration(milliseconds: 1));
      expect(requests, hasLength(1));

      conversation.loadingState.value = Success([other, target]);
      final (options, handler) = requests.single;
      handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          headers: Headers.fromMap({
            'Grpc-Status': ['0'],
          }),
          data: GrpcReq.compressProtobuf(RspSendMsg().writeToBuffer()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
      await recall;
      expect(target.msgStatus, 1);
      expect(other.msgStatus, 0);
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 150));

      final recallDuringReload = conversation.sendMsg(
        message: '200',
        msgType: MsgType.EN_MSG_TYPE_DRAW_BACK,
        onClearText: () => fail('recall must not clear the draft'),
      );
      await tester.pump(const Duration(milliseconds: 1));
      conversation.loadingState.value = LoadingState.loading();
      final (reloadOptions, reloadHandler) = requests.last;
      reloadHandler.resolve(
        Response(
          requestOptions: reloadOptions,
          statusCode: 200,
          headers: Headers.fromMap({
            'Grpc-Status': ['0'],
          }),
          data: GrpcReq.compressProtobuf(RspSendMsg().writeToBuffer()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
      await recallDuringReload;
      expect(conversation.loadingState.value, isA<Loading>());
      expect(find.text('撤回成功'), findsOneWidget);

      conversation.onDelete();
      await conversation.sendMsg(message: 'closed', onClearText: () {});
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 150));
      expect(requests, hasLength(2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('message badges skip guests and ignore old accounts and routes', (
    tester,
  ) async {
    final index = AccountType.main.index;
    final previous = Accounts.accountMode[index];
    Accounts.accountMode[index] = AnonymousAccount();
    addTearDown(() => Accounts.accountMode[index] = previous);
    Request();
    final unread = <(RequestOptions, RequestInterceptorHandler)>[];
    final mock = InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path.endsWith(GrpcUrl.getTotalUnread)) {
          unread.add((options, handler));
        } else if (options.path.endsWith(GrpcUrl.sessionMain)) {
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              headers: Headers.fromMap({
                'Grpc-Status': ['0'],
              }),
              data: GrpcReq.compressProtobuf(
                SessionMainReply().writeToBuffer(),
              ),
            ),
          );
        } else {
          handler.reject(DioException(requestOptions: options));
        }
      },
    );
    Request.dio.interceptors.insert(0, mock);
    addTearDown(() => Request.dio.interceptors.remove(mock));
    addTearDown(Get.reset);
    await tester.pumpWidget(
      GetMaterialApp(
        builder: FlutterSmartDialog.init(),
        home: const Scaffold(body: Text('首页')),
        getPages: [GetPage(name: '/whisper', page: WhisperPage.new)],
      ),
    );
    Get.toNamed<void>('/whisper');
    await tester.pumpAndSettle();
    final controller = Get.find<WhisperController>();
    expect(find.text('消息'), findsOneWidget);
    expect(unread, isEmpty);
    final guestRefresh = controller.onRefresh();
    await tester.pumpAndSettle();
    await guestRefresh;
    expect(unread, isEmpty);

    void replyWithCount(int count) {
      final (options, handler) = unread.last;
      final response = RspTotalUnread(
        msgFeedUnread: MsgFeedUnreadRsp(
          unread: {'reply': Int64(count)}.entries,
        ),
      );
      handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          headers: Headers.fromMap({
            'Grpc-Status': ['0'],
          }),
          data: GrpcReq.compressProtobuf(response.writeToBuffer()),
        ),
      );
    }

    Accounts.accountMode[index] = _Account();
    final oldRequest = controller.queryMsgFeedUnread();
    await tester.pump(const Duration(milliseconds: 1));
    expect(unread, hasLength(1));
    Accounts.accountMode[index] = _Account(22);
    replyWithCount(99);
    await tester.pump(const Duration(milliseconds: 1));
    await oldRequest;
    expect(controller.unreadCounts, everyElement(0));

    final activeRequest = controller.queryMsgFeedUnread();
    await tester.pump(const Duration(milliseconds: 1));
    expect(unread, hasLength(2));
    replyWithCount(8);
    await tester.pump(const Duration(milliseconds: 1));
    await activeRequest;
    expect(controller.unreadCounts.first, 8);

    final closedRequest = controller.queryMsgFeedUnread();
    await tester.pump(const Duration(milliseconds: 1));
    expect(unread, hasLength(3));
    Get.back();
    await tester.pumpAndSettle();
    expect(controller.isClosed, isTrue);
    final (options, handler) = unread.last;
    handler.reject(
      DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
    await closedRequest;
    await tester.pump(const Duration(milliseconds: 200));
    expect(controller.unreadCounts.first, 8);
    expect(find.textContaining('响应超时'), findsNothing);
    expect(find.text('首页'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
