import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixnum/fixnum.dart';
import 'package:get/get.dart';
import 'package:PiliPlus/grpc/bilibili/im/type.pb.dart';
import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:PiliPlus/pages/whisper/message_route.dart';
import 'package:PiliPlus/pages/whisper_detail/widget/chat_item.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'helpers/memory_box.dart';

void main() {
  setUpAll(() {
    GStorage.setting = MemoryBox();
    Pref.captureAppearanceAtStartup();
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
