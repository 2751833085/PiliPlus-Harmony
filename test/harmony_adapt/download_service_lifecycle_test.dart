import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/models/common/video/video_type.dart';
import 'package:PiliPlus/models_new/download/bili_download_media_file_info.dart';
import 'package:PiliPlus/utils/path_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';

import 'helpers/memory_box.dart';
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

BiliDownloadEntryInfo _entry(String root, {int cid = 1}) =>
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
        pageData: PageInfo(cid: cid, page: 1, hasAlias: false, tid: 0),
      )
      ..pageDirPath = root
      ..entryDirPath = '$root/c_$cid';

class _LocalMedia extends DownloadService {
  _LocalMedia(this.origin, {this.hasAudio = false, this.manifest});

  final Uri origin;
  final bool hasAudio;
  final Type2? manifest;
  @override
  Future<bool> downloadDanmaku({
    required BiliDownloadEntryInfo entry,
    bool isUpdate = false,
    bool Function()? isCurrent,
  }) async => true;

  @override
  Future<BiliDownloadMediaInfo> resolveMedia(
    BiliDownloadEntryInfo entry,
    CancelToken cancel,
  ) async =>
      manifest ??
      Type2(
        video: [_asset('/${entry.cid}')],
        audio: hasAudio ? [_asset('/audio-${entry.cid}')] : null,
      );

  Type2File _asset(String path) => Type2File(
    id: 80,
    baseUrl: origin.resolve(path).toString(),
    bandwidth: 1,
    codecid: 7,
    size: 4,
    md5: '',
    noRexcode: false,
  );
}

class _CachedDanmaku extends DownloadService {
  @override
  Future<bool> downloadDanmaku({
    required BiliDownloadEntryInfo entry,
    bool isUpdate = false,
    bool Function()? isCurrent,
  }) async => true;
}

void _stubManifest(Map<String, Object?> manifest) {
  final stub = InterceptorsWrapper(
    onRequest: (options, handler) {
      if (options.path == VideoType.ugc.api) {
        handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: {'code': 0, 'data': manifest},
          ),
        );
      } else {
        handler.next(options);
      }
    },
  );
  Request.dio.interceptors.insert(0, stub);
  addTearDown(() => Request.dio.interceptors.remove(stub));
}

Map<String, Object?> _durl(String url, {int order = 1}) => {
  'order': order,
  'length': 30000,
  'size': 4,
  'url': url,
};

Future<void> _waitUntil(bool Function() condition) async {
  final stopwatch = Stopwatch()..start();
  while (!condition()) {
    if (stopwatch.elapsed > const Duration(seconds: 5)) {
      fail('download did not reach the expected state');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  late Directory root;
  setUpAll(() {
    GStorage.setting = MemoryBox();
    GStorage.localCache = MemoryBox()
      ..put(LocalCacheKey.timeStamp, DateTime.now().millisecondsSinceEpoch)
      ..put(LocalCacheKey.mixinKey, 'fixture-signing-key');
    Request();
    Request.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.path = options.path.replaceFirst(
            'https://127.0.0.1',
            'http://127.0.0.1',
          );
          handler.next(options);
        },
      ),
    );
  });
  tearDownAll(() => Request.dio.close(force: true));
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
  test(
    'disk failure at completion stays retryable and does not publish a completed entry',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final service = _LocalMedia(Uri.parse('http://127.0.0.1:${server.port}'));
      final entry = _entry(root.path);
      await File(
        '${entry.entryDirPath}/${PathUtils.coverName}',
      ).writeAsBytes([0]);
      final metadata = File('${entry.entryDirPath}/entry.json');
      await metadata.writeAsString(jsonEncode(entry.toJson()));
      final blockedMetadata = Directory('${metadata.path}.tmp');
      await blockedMetadata.create();
      final ranges = <String?>[];
      server.listen((request) async {
        final range = request.headers.value(HttpHeaders.rangeHeader);
        ranges.add(range);
        if (range == 'bytes=4-') {
          request.response.statusCode = 416;
          request.response.headers.set('Content-Range', 'bytes */4');
        } else {
          request.response.contentLength = 4;
          request.response.add([1, 2, 3, 4]);
        }
        await request.response.close();
      });
      service.waitDownloadQueue.add(entry);
      await service.startDownload(entry);
      await _waitUntil(() => entry.status == DownloadStatus.failDownload);
      expect(entry.isCompleted, isFalse);
      expect(service.downloadList, isEmpty);
      expect(service.waitDownloadQueue, [entry]);
      expect(
        jsonDecode(await metadata.readAsString())['is_completed'],
        isFalse,
      );
      final video = File(
        '${entry.entryDirPath}/80/${PathUtils.videoNameType2}',
      );
      expect(await video.readAsBytes(), [1, 2, 3, 4]);

      await blockedMetadata.delete();
      await service.startDownload(entry);
      await _waitUntil(() => service.downloadList.contains(entry));
      expect(ranges, ['bytes=0-', 'bytes=4-']);
      expect(entry.isCompleted, isTrue);
      expect(service.waitDownloadQueue, isEmpty);
      expect(jsonDecode(await metadata.readAsString())['is_completed'], isTrue);
    },
  );

  test('a pending pause cannot clear a later active download', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final service = _LocalMedia(Uri.parse('http://127.0.0.1:${server.port}'));
    final first = _entry(root.path);
    final second = _entry(root.path, cid: 2);
    await Directory(second.entryDirPath).create();
    for (final entry in [first, second]) {
      await File(
        '${entry.entryDirPath}/${PathUtils.coverName}',
      ).writeAsBytes([0]);
    }
    final release = Completer<void>();
    addTearDown(() {
      if (!release.isCompleted) release.complete();
    });
    server.listen((request) async {
      request.response.bufferOutput = false;
      request.response.contentLength = 4;
      if (request.uri.path == '/1') {
        request.response.add([1, 2]);
        await request.response.flush();
        await release.future;
      } else {
        request.response.add([3, 4, 5, 6]);
      }
      try {
        await request.response.close();
      } catch (_) {}
    });
    service.waitDownloadQueue.addAll([first, second]);
    await service.startDownload(first);
    await _waitUntil(() => first.downloadedBytes == 2);
    final pause = service.cancelDownload(isDelete: false, downloadNext: false);
    final start = service.startDownload(second);
    await Future.wait([pause, start]);
    // Stop the queue from automatically continuing the intentionally paused item.
    service.waitDownloadQueue.remove(first);
    await _waitUntil(() => service.downloadList.contains(second));
    expect(first.status, DownloadStatus.pause);
    expect(second.status, DownloadStatus.completed);
    expect(service.curDownload.value, isNull);
    expect(
      await File(
        '${second.entryDirPath}/80/${PathUtils.videoNameType2}',
      ).readAsBytes(),
      [3, 4, 5, 6],
    );
  });
  test(
    'deleting the parent cache removes all of its queued and preparing entries',
    () async {
      final service = _SlowPreparation();
      final entry = _entry(root.path);
      final queued = _entry(root.path, cid: 2);
      service.waitDownloadQueue.addAll([entry, queued]);
      final start = service.startDownload(entry);
      await service.started.future;
      await service
          .deletePage(pageDirPath: root.path)
          .timeout(const Duration(seconds: 2));
      await start.timeout(const Duration(seconds: 2));
      service.response.complete(true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(service.curDownload.value, isNull);
      expect(service.waitDownloadQueue, isEmpty);
      expect(await root.exists(), isFalse);
    },
  );

  test(
    'deleting an absent entry preserves its only remaining sibling',
    () async {
      final service = _SlowPreparation();
      final sibling = _entry(root.path);
      final missing = _entry(root.path, cid: 2);
      final data = File('${sibling.entryDirPath}/media');
      await data.writeAsBytes([1, 2, 3]);
      await service.deleteDownload(entry: missing, removeQueue: true);
      expect(await data.readAsBytes(), [1, 2, 3]);
    },
  );

  test(
    'audio failure keeps video bytes but never completes the cache entry',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final service = _LocalMedia(
        Uri.parse('http://127.0.0.1:${server.port}'),
        hasAudio: true,
      );
      final entry = _entry(root.path);
      await File(
        '${entry.entryDirPath}/${PathUtils.coverName}',
      ).writeAsBytes([0]);
      final audioRejected = Completer<void>();
      final releaseVideo = Completer<void>();
      var verifiedAudioFailure = false;
      addTearDown(() async {
        if (!releaseVideo.isCompleted) releaseVideo.complete();
        // The failure status is visible before the service saves its entry.
        // Pausing joins both media tasks and queues a final metadata write
        // behind any earlier saves, before the fixture directory is removed.
        await service.cancelDownload(isDelete: false, downloadNext: false);
        if (verifiedAudioFailure) {
          final metadata = File('${entry.entryDirPath}/entry.json');
          final saved = jsonDecode(await metadata.readAsString()) as Map;
          expect(saved['is_completed'], isFalse);
          expect(saved['downloaded_bytes'], 4);
        }
      });
      server.listen((request) async {
        request.response.bufferOutput = false;
        if (request.uri.path.startsWith('/audio-')) {
          request.response.contentLength = 0;
          await request.response.close();
          audioRejected.complete();
          return;
        }
        request.response.contentLength = 4;
        request.response.add([1, 2]);
        await request.response.flush();
        await releaseVideo.future;
        request.response.add([3, 4]);
        await request.response.close();
      });
      service.waitDownloadQueue.add(entry);
      await service.startDownload(entry);
      await audioRejected.future.timeout(const Duration(seconds: 2));
      await _waitUntil(() => entry.downloadedBytes == 2);
      expect(entry.status, DownloadStatus.downloading);
      releaseVideo.complete();
      await _waitUntil(() => entry.status == DownloadStatus.failDownloadAudio);
      expect(entry.isCompleted, isFalse);
      expect(service.downloadList, isEmpty);
      expect(
        await File(
          '${entry.entryDirPath}/80/${PathUtils.videoNameType2}',
        ).readAsBytes(),
        [1, 2, 3, 4],
      );
      verifiedAudioFailure = true;
    },
  );
  for (final dash in [false, true]) {
    test(
      'download retry records actual ${dash ? 'DASH' : 'MP4'} files and clears stale audio',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        final mediaUrl = 'http://127.0.0.1:${server.port}/video';
        server.listen((request) async {
          expect(request.uri.path, '/video');
          request.response.contentLength = 4;
          request.response.add([1, 2, 3, 4]);
          await request.response.close();
        });
        _stubManifest({
          'format': 'mp4',
          'quality': 80,
          'support_formats': [
            {
              'quality': 80,
              'codecs': ['avc1'],
            },
          ],
          if (dash)
            'dash': {
              'duration': 60,
              'video': [
                {
                  'id': 80,
                  'baseUrl': mediaUrl,
                  'codecs': 'avc1.640028',
                  'codecid': 7,
                  'bandwidth': 1,
                  'width': 1920,
                  'height': 1080,
                },
              ],
            }
          else
            'durl': [_durl(mediaUrl)],
        });

        final entry = _entry(root.path)
          ..mediaType = dash ? 1 : 2
          ..hasDashAudio = true;
        final metadata = File('${entry.entryDirPath}/entry.json');
        await metadata.writeAsString(jsonEncode(entry.toJson()));
        await File(
          '${entry.entryDirPath}/${PathUtils.coverName}',
        ).writeAsBytes([0]);
        final service = _CachedDanmaku();
        service.waitDownloadQueue.add(entry);
        await service.startDownload(entry);
        await _waitUntil(() => service.downloadList.contains(entry));

        final saved = BiliDownloadEntryInfo.fromJson(
          jsonDecode(await metadata.readAsString()),
        );
        expect(saved.isCompleted, isTrue);
        expect(saved.mediaType, dash ? 2 : 1);
        expect(saved.hasDashAudio, isFalse);
        final file = saved.mediaType == 1
            ? PathUtils.videoNameType1
            : PathUtils.videoNameType2;
        expect(await File('${entry.entryDirPath}/80/$file').readAsBytes(), [
          1,
          2,
          3,
          4,
        ]);
      },
    );
  }

  test(
    'multi-segment MP4 is not marked as complete after downloading only the first part',
    () async {
      final mediaRequests = <String>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final mediaUrl = 'http://127.0.0.1:${server.port}';
      server.listen((request) async {
        mediaRequests.add(request.uri.path);
        request.response.contentLength = 4;
        request.response.add([1, 2, 3, 4]);
        await request.response.close();
      });
      _stubManifest({
        'format': 'mp4',
        'quality': 80,
        'durl': [_durl('$mediaUrl/first'), _durl('$mediaUrl/second', order: 2)],
      });
      final entry = _entry(root.path);
      final metadata = File('${entry.entryDirPath}/entry.json');
      await metadata.writeAsString(jsonEncode(entry.toJson()));
      await File(
        '${entry.entryDirPath}/${PathUtils.coverName}',
      ).writeAsBytes([0]);
      final service = _CachedDanmaku();
      service.waitDownloadQueue.add(entry);
      await service.startDownload(entry);

      expect(entry.status, DownloadStatus.failPlayUrl);
      expect(entry.isCompleted, isFalse);
      expect(service.downloadList, isEmpty);
      expect(mediaRequests, isEmpty);
      expect(
        jsonDecode(await metadata.readAsString())['is_completed'],
        isFalse,
      );
    },
  );

  test(
    'malformed DASH metadata does not change the retry quality or format',
    () async {
      _stubManifest({
        'support_formats': [
          {
            'quality': 64,
            'codecs': ['avc1'],
          },
        ],
        'dash': {
          'duration': 60,
          'video': [
            {
              'id': 64,
              'baseUrl': 'http://127.0.0.1:1/never-requested',
              'codecs': 'avc1.640028',
              'codecid': 7,
              'bandwidth': 1,
              'width': 1280,
              'height': 720,
            },
          ],
          'audio': [
            {'id': 30280},
          ],
        },
      });
      final entry = _entry(root.path)
        ..videoQuality = 80
        ..qualityPithyDescription = '原画质';
      final service = _CachedDanmaku();
      service.waitDownloadQueue.add(entry);
      await service.startDownload(entry);

      expect(entry.status, DownloadStatus.failPlayUrl);
      expect(entry.isCompleted, isFalse);
      expect(entry.mediaType, 1);
      expect(entry.hasDashAudio, isFalse);
      expect(entry.typeTag, '80');
      expect(entry.preferedVideoQuality, 80);
      expect(entry.videoQuality, 80);
      expect(entry.qualityPithyDescription, '原画质');
      expect(service.downloadList, isEmpty);
    },
  );

  for (final change in [
    'signature',
    'video codec',
    'audio codec',
    'path',
    'missing index',
    'missing codec field',
  ]) {
    test('download resume validates $change before sending Range', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final origin = Uri.parse('http://127.0.0.1:${server.port}');
      const videoPath = '/video.m4s';
      const audioPath = '/audio.m4s';
      Type2File track(String path, int codec, String token, {int id = 80}) =>
          Type2File(
            id: id,
            baseUrl: origin.resolve('$path?upsig=$token').toString(),
            bandwidth: 1000,
            codecid: codec,
            size: 4,
            md5: '',
            noRexcode: false,
          );
      final oldManifest = Type2(
        video: [track(change == 'path' ? '/other.m4s' : videoPath, 7, 'old')],
        audio: [track(audioPath, 0, 'old', id: 30280)],
      );
      final newManifest = Type2(
        video: [track(videoPath, change == 'video codec' ? 12 : 7, 'new')],
        audio: [
          track(audioPath, change == 'audio codec' ? 1 : 0, 'new', id: 30280),
        ],
      );
      final ranges = <String, String?>{};
      server.listen((request) async {
        final path = request.uri.path;
        final range = request.headers.value(HttpHeaders.rangeHeader);
        ranges[path] = range;
        // A different representation can have the same byte count and return a
        // perfectly valid 206. Only the manifest identifies the mismatch.
        final bytes = switch (path) {
          videoPath when change == 'video codec' || change == 'path' => [
            9,
            8,
            7,
            6,
          ],
          videoPath => [1, 2, 3, 4],
          audioPath when change == 'audio codec' => [19, 18, 17, 16],
          _ => [11, 12, 13, 14],
        };
        if (range == 'bytes=2-') {
          request.response.statusCode = HttpStatus.partialContent;
          request.response.headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes 2-3/4',
          );
          request.response.contentLength = 2;
          request.response.add(bytes.sublist(2));
        } else {
          request.response.contentLength = 4;
          request.response.add(bytes);
        }
        await request.response.close();
      });
      final entry = _entry(root.path);
      await File(
        '${entry.entryDirPath}/${PathUtils.coverName}',
      ).writeAsBytes([0]);
      final folder = await Directory('${entry.entryDirPath}/80').create();
      final video = File('${folder.path}/${PathUtils.videoNameType2}');
      final audio = File('${folder.path}/${PathUtils.audioNameType2}');
      await video.writeAsBytes([1, 2]);
      await audio.writeAsBytes([11, 12]);
      final index = File('${folder.path}/index.json');
      final savedIndex = oldManifest.toJson();
      if (change == 'missing codec field') {
        (savedIndex['video'] as List<Map<String, dynamic>>).first.remove(
          'codecid',
        );
      }
      final oldIndex = jsonEncode(savedIndex);
      if (change != 'missing index') await index.writeAsString(oldIndex);
      final service = _LocalMedia(origin, manifest: newManifest);
      addTearDown(
        () => service.cancelDownload(isDelete: false, downloadNext: false),
      );
      service.waitDownloadQueue.add(entry);
      await service.startDownload(entry);

      if (change == 'signature') {
        await _waitUntil(() => service.downloadList.contains(entry));
        expect(ranges, {videoPath: 'bytes=2-', audioPath: 'bytes=2-'});
        expect(await video.readAsBytes(), [1, 2, 3, 4]);
        expect(await audio.readAsBytes(), [11, 12, 13, 14]);
        expect(await index.readAsString(), jsonEncode(newManifest.toJson()));
      } else {
        expect(entry.status, DownloadStatus.failPlayUrl);
        expect(entry.isCompleted, isFalse);
        expect(service.downloadList, isEmpty);
        expect(ranges, isEmpty);
        expect(await video.readAsBytes(), [1, 2]);
        expect(await audio.readAsBytes(), [11, 12]);
        if (change == 'missing index') {
          expect(index.existsSync(), isFalse);
        } else {
          expect(await index.readAsString(), oldIndex);
        }
      }
    });
  }
}
