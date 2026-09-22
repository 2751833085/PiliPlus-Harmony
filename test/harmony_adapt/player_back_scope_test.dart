import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'helpers/memory_box.dart';
import 'package:PiliPlus/common/widgets/flutter/pop_scope.dart' as app;
import 'package:PiliPlus/plugin/pl_player/widgets/back_scope.dart';
import 'package:PiliPlus/pages/common/publish/publish_route.dart';
import 'package:PiliPlus/pages/video/pay_coins/view.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/models/user/info.dart';

void main() {
  setUpAll(() {
    // The real coin widget reads preferences and may initialize default values.
    // Keep those local writes synchronous in widget-test fake time.
    GStorage.setting = MemoryBox<dynamic>();
    GStorage.localCache = MemoryBox<dynamic>();
    GStorage.userInfo = MemoryBox<UserInfoData>();
  });
  tearDown(Get.reset);

  for (final fullscreen in [false, true]) {
    testWidgets(
      'system back closes coin modal, comments, then player (fullscreen=$fullscreen)',
      (tester) async {
        final nav = GlobalKey<NavigatorState>();
        final playerKey = GlobalKey();
        var comments = true;
        var full = fullscreen;
        var playerBacks = 0;
        var paid = 0;
        await tester.pumpWidget(
          GetMaterialApp(
            navigatorKey: nav,
            home: const Scaffold(body: Text('home')),
          ),
        );
        nav.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => StatefulBuilder(
              builder: (context, setState) {
                return app.popScope(
                  canPop: !comments,
                  onPopInvokedWithResult: (didPop, _) {
                    if (!didPop && comments) setState(() => comments = false);
                  },
                  child: PlayerBackScope(
                    key: playerKey,
                    canPop: !full,
                    suspended: comments,
                    onPopInvokedWithResult: (didPop, _) {
                      playerBacks++;
                      if (!didPop) setState(() => full = false);
                    },
                    child: Scaffold(
                      body: Text(comments ? 'comments' : 'video'),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(playerKey.currentState?.mounted, true);
        // Same PopupRoute and actual coin widget as production; payment is a spy.
        nav.currentState!.push(
          PublishRoute<void>(
            pageBuilder: (_, __, ___) => PayCoinsPage(
              onPayCoin: (_, __) => paid++,
              hasCoin: false,
              hasCopyright: false,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(PayCoinsPage), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(PayCoinsPage), findsNothing);
        expect(find.text('comments'), findsOneWidget);
        expect(playerBacks, 0);
        expect(paid, 0);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('video'), findsOneWidget);
        expect(playerBacks, 0);
        if (fullscreen) {
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.text('video'), findsOneWidget);
          expect(playerBacks, 1);
        }
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('home'), findsOneWidget);
        expect(playerBacks, fullscreen ? 2 : 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'pop scopes register with the ancestor modal even without cached Get routing',
    (tester) async {
      final nav = GlobalKey<NavigatorState>();
      var modalBacks = 0;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          home: const Scaffold(body: Text('home')),
        ),
      );
      nav.currentState!.push(
        PublishRoute<void>(
          pageBuilder: (_, __, ___) => app.popScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) modalBacks++;
            },
            child: const Material(child: Text('modal')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(modalBacks, 1);
      expect(find.text('modal'), findsOneWidget);
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
