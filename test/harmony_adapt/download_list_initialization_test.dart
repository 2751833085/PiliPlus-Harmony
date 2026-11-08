import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:PiliPlus/harmony_adapt/widgets/harmony_loading.dart';
import 'package:PiliPlus/models_new/download/bili_download_entry_info.dart';
import 'package:PiliPlus/pages/download/controller.dart';
import 'package:PiliPlus/pages/download/view.dart';
import 'package:PiliPlus/services/download/download_service.dart';
import 'package:PiliPlus/utils/path_utils.dart';
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

BiliDownloadEntryInfo _entry(int id, int part, {String? cover}) =>
    BiliDownloadEntryInfo(
      isCompleted: true,
      totalBytes: 0,
      downloadedBytes: 0,
      title: '视频 $id 分集 $part',
      cover: cover ?? 'cover-$id-$part',
      preferedVideoQuality: 80,
      guessedTotalBytes: 0,
      totalTimeMilli: 1000,
      danmakuCount: 0,
      avid: id,
      bvid: 'BV1xx411c7mD',
      pageData: PageInfo(
        cid: id * 10 + part,
        page: part,
        hasAlias: false,
        tid: 0,
      ),
    )..pageDirPath = '/test/$id';

void main() {
  _PendingDownloads registerPendingDownloads() {
    final service = _PendingDownloads();
    Get.put<DownloadService>(service);
    return service;
  }

  setUpAll(() {
    GStorage.setting = MemoryBox();
    GStorage.watchProgress = MemoryBox();
  });
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

  testWidgets('failed cache scan retries once and preserves a paused task', (
    tester,
  ) async {
    final root = await tester.runAsync(
      () => Directory.systemTemp.createTemp('download-retry-fixture-'),
    );
    addTearDown(() => root!.delete(recursive: true));
    downloadPath = '${root!.path}/cache';
    final service = (await tester.runAsync(() async {
      await File(downloadPath).create();
      final downloads = Get.put(DownloadService());
      // The I/O Future and the controller awaiting its error share a zone.
      Get.put(DownloadPageController());
      await expectLater(
        downloads.waitForInitialization,
        throwsA(isA<FileSystemException>()),
      );
      return downloads;
    }))!;
    await tester.pumpWidget(
      GetMaterialApp(
        theme: HarmonyTheme.apply(
          ThemeData(platform: TargetPlatform.ohos),
          immersive: true,
        ),
        home: const DownloadPage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('无法读取离线缓存'), findsOneWidget);
    final retry = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '点击重试'),
    );
    final paused = _entry(1, 2, cover: '')
      ..isCompleted = false
      ..status = DownloadStatus.pause
      ..pageDirPath = '$downloadPath/1'
      ..entryDirPath = '$downloadPath/1/c_12';
    final finished = _entry(1, 1, cover: '')
      ..pageDirPath = '$downloadPath/1'
      ..entryDirPath = '$downloadPath/1/c_11';
    final interrupted = _entry(2, 1, cover: '')
      ..isCompleted = false
      ..status = DownloadStatus.downloading
      ..typeTag = '80'
      ..totalBytes = 100
      ..downloadedBytes = 3
      ..pageDirPath = '$downloadPath/2'
      ..entryDirPath = '$downloadPath/2/c_21';
    final partial = File('${interrupted.entryDirPath}/80/video.m4s');
    await tester.runAsync(() async {
      await File(downloadPath).delete();
      for (final entry in [paused, finished, interrupted]) {
        await Directory(entry.entryDirPath).create(recursive: true);
        await File('${entry.entryDirPath}/entry.json').writeAsString(
          jsonEncode(entry.toJson()),
        );
      }
      await partial.parent.create();
      await partial.writeAsBytes([1, 2, 3]);
      service.waitDownloadQueue.add(paused);
      retry.onPressed!();
      final scan = service.waitForInitialization;
      retry.onPressed!();
      service.initDownloadList();
      expect(service.waitForInitialization, same(scan));
      await scan;
    });
    await tester.pumpAndSettle();

    expect(find.text('点击重试'), findsNothing);
    expect(find.text('已缓存视频'), findsOneWidget);
    expect(find.text(finished.title), findsOneWidget);
    expect(service.downloadList.map((entry) => entry.cid), [finished.cid]);
    expect(service.waitDownloadQueue.map((entry) => entry.cid), [
      paused.cid,
      interrupted.cid,
    ]);
    expect(service.waitDownloadQueue.first, same(paused));
    expect(paused.status, DownloadStatus.pause);
    final recovered = service.waitDownloadQueue.last;
    expect(recovered.status, DownloadStatus.wait);
    expect(recovered.downloadedBytes, 3);
    expect(await tester.runAsync(partial.readAsBytes), [1, 2, 3]);
    expect(service.curDownload.value, isNull);
    expect(tester.takeException(), isNull);
  });
}
