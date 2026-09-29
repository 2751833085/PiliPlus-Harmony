import 'package:PiliPlus/models_new/space/space/level_info.dart';
import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:PiliPlus/models_new/space/space/card.dart';
import 'package:PiliPlus/models_new/space/space/images.dart';
import 'package:PiliPlus/pages/member/widget/user_info_card.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/memory_box.dart';

void main() {
  setUpAll(() {
    GStorage.setting = MemoryBox();
    GStorage.localCache = MemoryBox();
  });
  for (final width in [390.0, 760.0, 1108.0]) {
    testWidgets('profile header retains controls without overflow at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final pages = PageController();
      addTearDown(pages.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: HarmonyTheme.apply(ThemeData(), immersive: true),
          home: Scaffold(
            body: SingleChildScrollView(
              child: UserInfoCard(
                isOwner: false,
                card: SpaceCard(
                  mid: '1',
                  levelInfo: LevelInfo(currentLevel: 6),
                  name: '用户名称',
                  face: '',
                  sign: '个人简介',
                  fans: 100,
                  attention: 10,
                ),
                images: SpaceImages(imgUrl: '', nightImgurl: ''),
                relation: 0,
                onFollow: () {},
                headerControllerBuilder: () => pages,
                showLiveMedalWall: () {},
                charges: null,
                chargeCount: null,
                guards: null,
                guardCount: null,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('用户名称'), findsOneWidget);
      expect(find.byIcon(Icons.mail_outline), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
