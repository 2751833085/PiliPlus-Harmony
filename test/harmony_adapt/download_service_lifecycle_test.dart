import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/services/download/download_service.dart';
import 'package:PiliPlus/models_new/download/bili_download_entry_info.dart';

class _SlowPreparation extends DownloadService {
  final started = Completer<void>();
  final response = Completer<bool>();
  @override
  Future<bool> downloadDanmaku({
    required BiliDownloadEntryInfo entry,
    bool isUpdate = false,
    bool Function()? isCurrent,
  }) {
    entry.status = DownloadStatus.getDanmaku;
    started.complete();
    return response.future;
  }
}

BiliDownloadEntryInfo _entry(String root) =>
    BiliDownloadEntryInfo(
        isCompleted: false,
        totalBytes: 0,
        downloadedBytes: 0,
        title: 'test',
        typeTag: '80',
        cover: 'https://cdn.test/cover',
        preferedVideoQuality: 80,
        guessedTotalBytes: 0,
        totalTimeMilli: 60000,
        danmakuCount: 0,
        avid: 1,
        bvid: 'BV1xx411c7mD',
        pageData: PageInfo(cid: 1, page: 1, hasAlias: false, tid: 0),
      )
      ..pageDirPath = root
      ..entryDirPath = '$root/c_1';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('download-prepare-');
    await Directory('${root.path}/c_1').create();
  });
  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });
  test(
    'pause returns promptly during preparation and late response cannot restart media',
    () async {
      final service = _SlowPreparation();
      final entry = _entry(root.path);
      service.waitDownloadQueue.add(entry);
      final start = service.startDownload(entry);
      await service.started.future;
      await service
          .cancelDownload(isDelete: false, downloadNext: false)
          .timeout(const Duration(seconds: 2));
      await start.timeout(const Duration(seconds: 2));
      expect(entry.status, DownloadStatus.pause);
      service.response.complete(true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(entry.status, DownloadStatus.pause);
      expect(await Directory('${entry.entryDirPath}/80').exists(), isFalse);
      expect(await File('${entry.entryDirPath}/entry.json').exists(), isTrue);
    },
  );
  test(
    'delete during preparation stays deleted after the request eventually completes',
    () async {
      final service = _SlowPreparation();
      final entry = _entry(root.path);
      service.waitDownloadQueue.add(entry);
      final start = service.startDownload(entry);
      await service.started.future;
      await service
          .deleteDownload(entry: entry, removeQueue: true, downloadNext: false)
          .timeout(const Duration(seconds: 2));
      await start.timeout(const Duration(seconds: 2));
      service.response.complete(true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(service.curDownload.value, isNull);
      expect(service.waitDownloadQueue, isEmpty);
      expect(await Directory(entry.entryDirPath).exists(), isFalse);
    },
  );
}
