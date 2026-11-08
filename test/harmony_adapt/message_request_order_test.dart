import 'dart:async';

import 'package:PiliPlus/grpc/bilibili/im/interfaces/v1.pb.dart'
    show RspSendMsg, RspSessionMsg;
import 'package:PiliPlus/grpc/bilibili/im/type.pb.dart' show Msg, MsgType;
import 'package:PiliPlus/grpc/grpc_req.dart';
import 'package:PiliPlus/grpc/url.dart';
import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/account_type.dart';
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

import 'helpers/memory_box.dart';

class _Account extends LoginAccount {
  _Account() : super(DefaultCookieJar(), null, null);

  @override
  int get mid => 11;
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

      conversation.onDelete();
      await conversation.sendMsg(message: 'closed', onClearText: () {});
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 150));
      expect(requests, hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
