import 'dart:async';

import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:PiliPlus/harmony_adapt/widgets/harmony_loading.dart';
import 'package:PiliPlus/models_new/download/bili_download_entry_info.dart';
import 'package:PiliPlus/pages/download/controller.dart';
import 'package:PiliPlus/pages/download/view.dart';
import 'package:PiliPlus/services/download/download_service.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers/memory_box.dart';

class _PendingDownloads extends DownloadService {
  final initialization = Completer<void>();

  @override
  void initDownloadList() {
    waitForInitialization = initialization.future;
  }
}

BiliDownloadEntryInfo _entry(int id, int part) => BiliDownloadEntryInfo(
  isCompleted: true,
  totalBytes: 0,
  downloadedBytes: 0,
  title: '视频 $id 分集 $part',
  cover: 'cover-$id-$part',
  preferedVideoQuality: 80,
  guessedTotalBytes: 0,
  totalTimeMilli: 1000,
  danmakuCount: 0,
  avid: id,
  bvid: 'BV1xx411c7mD',
  pageData: PageInfo(cid: id * 10 + part, page: part, hasAlias: false, tid: 0),
)..pageDirPath = '/test/$id';

void main() {
  _PendingDownloads registerPendingDownloads() {
    final service = _PendingDownloads();
    Get.put<DownloadService>(service);
    return service;
  }

  setUpAll(() => GStorage.setting = MemoryBox());
  tearDown(Get.reset);

  for (final scanFails in [false, true]) {
    testWidgets(
      'cache scan shows loading first, then ${scanFails ? 'the error' : 'the empty state'}',
      (tester) async {
        final service = registerPendingDownloads();
        await tester.pumpWidget(
          GetMaterialApp(
            theme: HarmonyTheme.apply(
              ThemeData(platform: TargetPlatform.ohos),
              immersive: true,
            ),
            home: const DownloadPage(),
          ),
        );
        final search = find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip == '搜索',
        );
        expect(find.text('离线缓存'), findsOneWidget);
        expect(find.byType(HttpError), findsNothing);
        expect(find.byType(HarmonyLoadingIndicator), findsOneWidget);
        expect(tester.widget<IconButton>(search).onPressed, isNull);

        if (scanFails) {
          service.initialization.completeError(StateError('test read failure'));
        } else {
          service.initialization.complete();
        }
        await tester.pumpAndSettle();

        final error = tester.widget<HttpError>(find.byType(HttpError));
        expect(error.errMsg, scanFails ? '无法读取离线缓存' : isNull);
        expect(find.byType(HarmonyLoadingIndicator), findsNothing);
        expect(
          tester.widget<IconButton>(search).onPressed,
          scanFails ? isNull : isNotNull,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'grouping preserves download order and picks the lowest part cover',
    (
      tester,
    ) async {
      final service = registerPendingDownloads();
      final controller = Get.put(DownloadPageController());
      final first = _entry(3, 3);
      final second = _entry(1, 1);
      final third = _entry(3, 2);
      service.downloadList.addAll([first, second, third]);
      service.initialization.complete();
      await tester.pump();

      expect(controller.pages.map((item) => item.pageId), ['3', '1']);
      final group = controller.pages.first;
      expect(group.entries, [first, third]);
      expect(group.title, first.title);
      expect(group.cover, third.cover);
      expect(group.sortKey, third.sortKey);
      expect(controller.initialLoad.value.isSuccess, isTrue);
    },
  );
}
