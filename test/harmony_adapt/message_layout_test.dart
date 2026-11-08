import 'package:PiliPlus/grpc/bilibili/app/im/v1.pb.dart'
    show PrivateId, Session, SessionId, SessionInfo, SessionMainReply;
import 'package:PiliPlus/grpc/bilibili/dagw/component/avatar/v1.pb.dart'
    show AvatarItem, BasicLayerResource, Layer, LayerGroup, ResImage;
import 'package:PiliPlus/grpc/bilibili/im/interfaces/v1.pb.dart'
    show RspSessionMsg;
import 'package:PiliPlus/grpc/bilibili/im/type.pb.dart' show Msg;
import 'package:PiliPlus/grpc/grpc_req.dart';
import 'package:PiliPlus/grpc/url.dart';
import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/pages/whisper/message_route.dart';
import 'package:PiliPlus/pages/whisper/view.dart';
import 'package:PiliPlus/pages/whisper_detail/view.dart';
import 'package:PiliPlus/pages/whisper_detail/widget/chat_item.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:dio/dio.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'helpers/memory_box.dart';

void main() {
  setUpAll(() {
    GStorage.setting = MemoryBox();
    GStorage.localCache = MemoryBox();
  });
  testWidgets(
    'chat bubbles wrap on native fold widths and keep neutral surfaces',
    (tester) async {
      for (final width in [1008.0, 2048.0, 3184.0]) {
        tester.view.devicePixelRatio = 2.875;
        tester.view.physicalSize = Size(width, 2232);
        for (final brightness in Brightness.values) {
          await tester.pumpWidget(
            MaterialApp(
              theme: HarmonyTheme.apply(
                ThemeData(brightness: brightness),
                immersive: true,
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(1.4)),
                child: child!,
              ),
              home: Scaffold(
                body: ListView(
                  children: [
                    for (final owner in [true, false])
                      ChatItem(
                        item: Msg(
                          msgType: 1,
                          timestamp: Int64(1700000000),
                          content:
                              '{"content":"这是一条用于验证聊天长文本换行与大小比例的消息。This is a long message on a folding screen."}',
                        ),
                        isOwner: owner,
                        showTimestamp: false,
                        eInfos: null,
                        onLongPress: () {},
                        onSecondaryTapUp: null,
                      ),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$width $brightness');
          expect(find.byType(SelectableText), findsNWidgets(2));
        }
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );
  for (final physicalWidth in [1008.0, 2048.0]) {
    testWidgets(
      'conversation covers a stationary message list at $physicalWidth px',
      (tester) async {
        const dpr = 2.875;
        tester.view
          ..devicePixelRatio = dpr
          ..physicalSize = Size(physicalWidth, 2232)
          ..padding = const FakeViewPadding(top: 72, bottom: 52)
          ..viewPadding = const FakeViewPadding(top: 72, bottom: 52);
        addTearDown(tester.view.reset);
        addTearDown(Get.reset);

        const name = '离线会话';
        final session = Session(
          id: SessionId(privateId: PrivateId(talkerUid: Int64(123))),
          sessionInfo: SessionInfo(
            sessionName: name,
            avatar: AvatarItem(
              fallbackLayers: LayerGroup(
                layers: [
                  Layer(resource: BasicLayerResource(resImage: ResImage())),
                ],
              ),
            ),
          ),
        );
        final requests = <String>[];
        Request();
        final stub = InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options.path);
            final reply = switch (options.path) {
              String path when path.endsWith(GrpcUrl.sessionMain) =>
                SessionMainReply(sessions: [session]).writeToBuffer(),
              String path when path.endsWith(GrpcUrl.syncFetchSessionMsgs) =>
                RspSessionMsg().writeToBuffer(),
              _ => null,
            };
            if (reply == null) {
              handler.reject(DioException(requestOptions: options));
              return;
            }
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                headers: Headers.fromMap({
                  'Grpc-Status': ['0'],
                }),
                data: GrpcReq.compressProtobuf(reply),
              ),
            );
          },
        );
        Request.dio.interceptors.insert(0, stub);
        addTearDown(() => Request.dio.interceptors.remove(stub));

        await tester.pumpWidget(
          GetMaterialApp(
            theme: HarmonyTheme.apply(ThemeData(), immersive: true),
            builder: FlutterSmartDialog.init(),
            home: const Scaffold(body: Text('首页')),
            getPages: [GetPage(name: '/whisper', page: WhisperPage.new)],
          ),
        );
        Get.toNamed<void>('/whisper');
        await tester.pumpAndSettle();

        final title = find.text('消息');
        final list = find.byKey(const PageStorageKey('message-list'));
        final detail = find.byType(WhisperDetailPage);
        final titleOrigin = tester.getTopLeft(title);
        final listOrigin = tester.getTopLeft(list);
        expect(listOrigin.dy, greaterThan(titleOrigin.dy));
        await tester.tap(find.text(name));
        await tester.pump();
        expect(tester.getTopLeft(title), titleOrigin);
        expect(tester.getTopLeft(list), listOrigin);
        expect(
          tester.getTopLeft(detail).dx,
          closeTo(physicalWidth / dpr, 0.01),
        );
        expect(tester.getTopLeft(detail).dy, 0);

        await tester.pump(const Duration(milliseconds: 95));
        expect(tester.getTopLeft(title), titleOrigin);
        expect(tester.getTopLeft(list), listOrigin);
        expect(
          tester.getTopLeft(detail).dx,
          inExclusiveRange(0, physicalWidth / dpr),
        );
        expect(tester.getTopLeft(detail).dy, 0);

        await tester.pumpAndSettle();
        expect(tester.getTopLeft(detail), Offset.zero);
        expect(title, findsNothing);
        expect(list, findsNothing);
        expect(requests, [
          endsWith(GrpcUrl.sessionMain),
          endsWith(GrpcUrl.syncFetchSessionMsgs),
        ]);

        await tester.tap(find.byTooltip('返回消息列表'));
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(title), titleOrigin);
        expect(tester.getTopLeft(list), listOrigin);
        expect(detail, findsNothing);
        expect(Get.currentRoute, '/whisper');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'message route retains arguments and returns without replacing home',
    (tester) async {
      Get.testMode = true;
      await tester.pumpWidget(
        GetMaterialApp(home: const Scaffold(body: Text('home'))),
      );
      Get.key.currentState!.push(
        HarmonyMessageRoute(
          settings: const RouteSettings(
            name: '/testMessage',
            arguments: {'talkerId': 123},
          ),
          page: () =>
              Scaffold(body: Text('talker:${Get.arguments['talkerId']}')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('talker:123'), findsOneWidget);
      Get.back();
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      Get.reset();
    },
  );
}
