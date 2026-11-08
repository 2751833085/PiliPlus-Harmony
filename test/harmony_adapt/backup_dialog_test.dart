import 'dart:async';

import 'package:PiliPlus/common/widgets/dialog/export_import.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  testWidgets(
    'backup clipboard confirmation survives closing its menu and hides credentials',
    (tester) async {
      final clipboard = Completer<Map<String, String>>();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            ..setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'Clipboard.getData') return clipboard.future;
              return null;
            });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      addTearDown(Get.reset);
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showImportExportDialog<Map>(
                  context,
                  title: '登录信息',
                  sensitive: true,
                  onExport: () => '{}',
                  onImport: (_) => fail('cancel must not import'),
                  localFileName: () => 'account',
                ),
                child: const Text('打开备份菜单'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开备份菜单'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('从剪贴板导入'));
      await tester.pumpAndSettle();
      expect(find.text('导入/导出登录信息'), findsNothing);
      clipboard.complete({'text': '{"session":"fixture-credential"}'});
      await tester.pumpAndSettle();
      expect(find.text('导入剪贴板中的登录信息？'), findsOneWidget);
      expect(
        find.textContaining('fixture-credential', findRichText: true),
        findsNothing,
      );
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.text('打开备份菜单'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
