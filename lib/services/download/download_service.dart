import 'dart:async';
import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:io' show Directory, File, FileSystemException;
import 'package:dio/dio.dart' show CancelToken;

import 'package:PiliPlus/grpc/dm.dart';
import 'package:PiliPlus/harmony_adapt/harmony_channel.dart';
import 'package:PiliPlus/http/download.dart';
import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/models/common/video/video_quality.dart';
import 'package:PiliPlus/models_new/download/bili_download_entry_info.dart';
import 'package:PiliPlus/models_new/download/bili_download_media_file_info.dart';
import 'package:PiliPlus/models_new/pgc/pgc_info_model/episode.dart' as pgc;
import 'package:PiliPlus/models_new/pgc/pgc_info_model/result.dart';
import 'package:PiliPlus/models_new/video/video_detail/data.dart';
import 'package:PiliPlus/models_new/video/video_detail/episode.dart' as ugc;
import 'package:PiliPlus/models_new/video/video_detail/page.dart';
import 'package:PiliPlus/services/download/download_manager.dart';
import 'package:PiliPlus/utils/cache_manager.dart';
import 'package:PiliPlus/utils/danmaku_utils.dart';
import 'package:PiliPlus/utils/extension/file_ext.dart';
import 'package:PiliPlus/utils/extension/string_ext.dart';
import 'package:PiliPlus/utils/id_utils.dart';
import 'package:PiliPlus/utils/path_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:os_type/os_type.dart';
import 'package:path/path.dart' as path;
import 'package:synchronized/synchronized.dart';

// ref https://github.com/10miaomiao/bilimiao2/blob/master/bilimiao-download/src/main/java/cn/a10miaomiao/bilimiao/download/DownloadService.kt

class DownloadService extends GetxService {
  static const _entryFile = 'entry.json';
  static const _indexFile = 'index.json';
  static const _maxDanmakuConcurrency = 4;

  final _lock = Lock();
  final _entryWriteLock = Lock();
  final _creatingCids = <int>{};
  int _downloadRevision = 0;
  CancelToken? _prepareCancel;
  bool _isCurrent(BiliDownloadEntryInfo entry, int revision) =>
      revision == _downloadRevision && identical(curDownload.value, entry);

  Future<T> _prepare<T>(Future<T> work, CancelToken cancel) => Future.any([
    work,
    cancel.whenCancel.then<T>((error) => throw error),
  ]);

  final flagNotifier = SetNotifier();
  final waitDownloadQueue = RxList<BiliDownloadEntryInfo>();
  final downloadList = <BiliDownloadEntryInfo>[];

  int? _curCid;
  int? get curCid => _curCid;
  final curDownload = Rxn<BiliDownloadEntryInfo>();
  void _updateCurStatus(DownloadStatus status) {
    if (curDownload.value != null) {
      curDownload
        ..value!.status = status
        ..refresh();
    }
  }

  DownloadManager? _downloadManager;
  DownloadManager? _audioDownloadManager;

  late Future<void> waitForInitialization;

  @override
  void onInit() {
    super.onInit();
    initDownloadList();
  }

  void initDownloadList() {
    waitForInitialization = _readDownloadList();
  }

  Future<void> _readDownloadList() async {
    downloadList.clear();
    final downloadDir = Directory(await _getDownloadPath());
    await for (final dir in downloadDir.list()) {
      if (dir is Directory) {
        downloadList.addAll(await _readDownloadDirectory(dir));
      }
    }
    downloadList.sort((a, b) => b.timeUpdateStamp.compareTo(a.timeUpdateStamp));
  }

  @pragma('vm:notify-debugger-on-exception')
  Future<List<BiliDownloadEntryInfo>> _readDownloadDirectory(
    Directory pageDir,
  ) async {
    final result = <BiliDownloadEntryInfo>[];

    if (!pageDir.existsSync()) {
      return result;
    }

    await for (final entryDir in pageDir.list()) {
      if (entryDir is Directory) {
        final entryFile = File(path.join(entryDir.path, _entryFile));
        if (entryFile.existsSync()) {
          try {
            final entryJson = await entryFile.readAsString();
            final entry = BiliDownloadEntryInfo.fromJson(jsonDecode(entryJson))
              ..pageDirPath = pageDir.path
              ..entryDirPath = entryDir.path;
            if (entry.isCompleted) {
              result.add(entry);
            } else {
              waitDownloadQueue.add(entry..status = DownloadStatus.wait);
            }
          } catch (_) {}
        }
      }
    }

    return result;
  }

  void downloadVideo(
    Part page,
    VideoDetailData? videoDetail,
    ugc.EpisodeItem? videoArc,
    VideoQuality videoQuality,
  ) {
    final cid = page.cid!;
    if (downloadList.indexWhere((e) => e.cid == cid) != -1) {
      return;
    }
    if (waitDownloadQueue.indexWhere((e) => e.cid == cid) != -1) {
      return;
    }
    final pageData = PageInfo(
      cid: cid,
      page: page.page!,
      from: page.from,
      part: page.part,
      vid: page.vid,
      hasAlias: false,
      tid: 0,
      width: 0,
      height: 0,
      rotate: 0,
      downloadTitle: '视频已缓存完成',
      downloadSubtitle: videoDetail?.title ?? videoArc!.title,
    );
    final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final entry = BiliDownloadEntryInfo(
      mediaType: 2,
      hasDashAudio: false,
      isCompleted: false,
      totalBytes: 0,
      downloadedBytes: 0,
      title: videoDetail?.title ?? videoArc!.title!,
      typeTag: videoQuality.code.toString(),
      cover: (videoDetail?.pic ?? videoArc!.cover!).http2https,
      preferedVideoQuality: videoQuality.code,
      qualityPithyDescription: videoQuality.desc,
      guessedTotalBytes: 0,
      totalTimeMilli: (page.duration ?? 0) * 1000,
      danmakuCount:
          videoDetail?.stat?.danmaku ?? videoArc?.arc?.stat?.danmaku ?? 0,
      timeUpdateStamp: currentTime,
      timeCreateStamp: currentTime,
      canPlayInAdvance: true,
      interruptTransformTempFile: false,
      avid: videoDetail?.aid ?? videoArc!.aid!,
      spid: 0,
      seasonId: null,
      ep: null,
      source: null,
      bvid: videoDetail?.bvid ?? videoArc!.bvid!,
      ownerId: videoDetail?.owner?.mid ?? videoArc?.arc?.author?.mid,
      ownerName: videoDetail?.owner?.name ?? videoArc?.arc?.author?.name,
      pageData: pageData,
    );
    _createDownload(entry);
  }

  void downloadBangumi(
    int index,
    PgcInfoModel pgcItem,
    pgc.EpisodeItem episode,
    VideoQuality quality,
  ) {
    final cid = episode.cid!;
    if (downloadList.indexWhere((e) => e.cid == cid) != -1) {
      return;
    }
    if (waitDownloadQueue.indexWhere((e) => e.cid == cid) != -1) {
      return;
    }
    final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final source = SourceInfo(
      avId: episode.aid!,
      cid: cid,
    );
    final ep = EpInfo(
      avId: source.avId,
      page: index,
      danmaku: source.cid,
      cover: episode.cover!,
      episodeId: episode.id!,
      index: episode.title!,
      indexTitle: episode.longTitle ?? '',
      showTitle: episode.showTitle,
      from: episode.from ?? 'bangumi',
      seasonType: pgcItem.type ?? (episode.from == 'pugv' ? -1 : 0),
      width: 0,
      height: 0,
      rotate: 0,
      link: episode.link ?? '',
      bvid: episode.bvid ?? IdUtils.av2bv(source.avId),
      sortIndex: index,
    );
    final entry = BiliDownloadEntryInfo(
      mediaType: 2,
      hasDashAudio: false,
      isCompleted: false,
      totalBytes: 0,
      downloadedBytes: 0,
      title: pgcItem.seasonTitle ?? pgcItem.title ?? '',
      typeTag: quality.code.toString(),
      cover: episode.cover!,
      preferedVideoQuality: quality.code,
      qualityPithyDescription: quality.desc,
      guessedTotalBytes: 0,
      totalTimeMilli:
          (episode.duration ?? 0) *
          (episode.from == 'pugv' ? 1000 : 1), // pgc millisec,, pugv sec
      danmakuCount: pgcItem.stat?.danmaku ?? 0,
      timeUpdateStamp: currentTime,
      timeCreateStamp: currentTime,
      canPlayInAdvance: true,
      interruptTransformTempFile: false,
      spid: 0,
      seasonId: pgcItem.seasonId!.toString(),
      bvid: episode.bvid ?? IdUtils.av2bv(source.avId),
      avid: source.avId,
      ep: ep,
      source: source,
      ownerId: pgcItem.upInfo?.mid,
      ownerName: pgcItem.upInfo?.uname,
      pageData: null,
    );
    _createDownload(entry);
  }

  Future<void> _createDownload(BiliDownloadEntryInfo entry) async {
    if (!_creatingCids.add(entry.cid)) return;
    try {
      final entryDir = await _getDownloadEntryDir(entry);
      entry
        ..pageDirPath = entryDir.parent.path
        ..entryDirPath = entryDir.path;
      if (!await _updateBiliDownloadEntryJson(entry)) {
        SmartDialog.showToast('无法写入缓存记录，请检查存储空间与缓存路径');
        return;
      }
      waitDownloadQueue.add(entry);
      if (curDownload.value?.status.isDownloading != true) {
        unawaited(startDownload(entry));
      }
    } on FileSystemException catch (error) {
      if (kDebugMode) debugPrint('create download entry: $error');
      SmartDialog.showToast('无法写入缓存记录，请检查存储空间与缓存路径');
    } finally {
      _creatingCids.remove(entry.cid);
    }
  }

  Future<Directory> _getDownloadEntryDir(BiliDownloadEntryInfo entry) async {
    late final String dirName;
    late final String pageDirName;
    if (entry.ep case final ep?) {
      dirName = 's_${entry.seasonId}';
      pageDirName = ep.episodeId.toString();
    } else if (entry.pageData case final page?) {
      dirName = entry.avid.toString();
      pageDirName = 'c_${page.cid}';
    }
    final pageDir = Directory(
      path.join(await _getDownloadPath(), dirName, pageDirName),
    );
    if (!pageDir.existsSync()) {
      await pageDir.create(recursive: true);
    }
    return pageDir;
  }

  static Future<String> _getDownloadPath() async {
    final dir = Directory(downloadPath);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  bool _isQueued(BiliDownloadEntryInfo entry) =>
      waitDownloadQueue.any((queued) => identical(queued, entry));

  Future<void> startDownload(BiliDownloadEntryInfo entry) {
    if (entry.isCompleted || !_isQueued(entry)) {
      return Future.value();
    }
    final revision = ++_downloadRevision;
    _prepareCancel?.cancel();
    final cancel = _prepareCancel = CancelToken();
    return _lock.synchronized(() async {
      if (revision != _downloadRevision) return;
      await _downloadManager?.cancel(isDelete: false);
      await _audioDownloadManager?.cancel(isDelete: false);
      if (revision != _downloadRevision) return;
      _downloadManager = null;
      _audioDownloadManager = null;
      if (curDownload.value case final curEntry?) {
        if (curEntry.status.isDownloading)
          curEntry.status = DownloadStatus.pause;
      }
      if (!_isQueued(entry)) {
        curDownload.refresh();
        _stopBackgroundTask();
        return;
      }
      _curCid = entry.cid;
      curDownload.value = entry..status = DownloadStatus.getDanmaku;
      waitDownloadQueue.refresh();
      await _startDownload(entry, revision, cancel);
    });
  }

  Future<bool> downloadDanmaku({
    required BiliDownloadEntryInfo entry,
    bool isUpdate = false,
    bool Function()? isCurrent,
  }) async {
    final cid = entry.pageData?.cid ?? entry.source?.cid;
    if (cid == null) {
      return false;
    }
    final danmakuFile = File(
      path.join(entry.entryDirPath, PathUtils.danmakuName),
    );
    if (isUpdate || !danmakuFile.existsSync()) {
      try {
        if (!isUpdate) {
          _updateCurStatus(DownloadStatus.getDanmaku);
        }
        final seg = (entry.totalTimeMilli / DmUtils.segLength).ceil();
        if (seg <= 0) {
          throw StateError('Invalid danmaku segment count: $seg');
        }

        final danmaku = (await DmGrpc.dmSegMobile(
          cid: cid,
          segmentIndex: 1,
        )).data;
        if (isCurrent != null && !isCurrent()) return false;
        for (var start = 2; start <= seg; start += _maxDanmakuConcurrency) {
          final end = start + _maxDanmakuConcurrency - 1;
          final responses = await Future.wait([
            for (var index = start; index <= seg && index <= end; index++)
              DmGrpc.dmSegMobile(cid: cid, segmentIndex: index),
          ]);
          if (isCurrent != null && !isCurrent()) return false;
          for (final response in responses) {
            danmaku.elems.addAll(response.data.elems);
          }
          responses.clear();
        }
        await danmakuFile.writeAsBytes(danmaku.writeToBuffer());

        return true;
      } catch (e) {
        if (!isUpdate && (isCurrent?.call() ?? true)) {
          _updateCurStatus(DownloadStatus.failDanmaku);
        }
        if (kDebugMode) SmartDialog.showToast(e.toString());
        return false;
      }
    }
    return true;
  }

  Future<bool> _downloadCover({
    required BiliDownloadEntryInfo entry,
    CancelToken? cancelToken,
  }) async {
    try {
      final filePath = path.join(entry.entryDirPath, PathUtils.coverName);
      if (File(filePath).existsSync()) {
        return true;
      }
      final file = (await CacheManager.manager.getFileFromCache(
        entry.cover,
      ))?.file;
      if (file != null) {
        await file.copy(filePath);
      } else {
        await Request.dio.download(
          entry.cover,
          filePath,
          cancelToken: cancelToken,
        );
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static String? _stableMediaPath(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.path.isEmpty ||
        uri.path == '/') {
      return null;
    }
    // The CDN host and authorization parameters can change on retries.
    return uri.path;
  }

  static Object? _resumeIdentity(BiliDownloadMediaInfo media, String file) {
    switch (media) {
      case Type1() when media.segmentList.length == 1:
        final segment = media.segmentList.single;
        final resource = _stableMediaPath(segment.url);
        if (resource == null) return null;
        return (
          resource,
          media.quality,
          media.format,
          media.videoCodecId,
          segment.order,
          segment.bytes,
          segment.duration,
          segment.md5,
        );
      case Type2():
        final track = file == PathUtils.audioNameType2
            ? media.audio?.firstOrNull
            : media.video.firstOrNull;
        if (track == null) return null;
        final resource = _stableMediaPath(track.baseUrl);
        if (resource == null) return null;
        return (
          resource,
          track.id,
          track.codecid,
          track.bandwidth,
          track.width,
          track.height,
          track.frameRate,
          track.dashDrmType,
          track.md5,
        );
      default:
        return null;
    }
  }

  Future<void> _verifyResumeIdentity(
    File index,
    BiliDownloadMediaInfo media,
  ) async {
    final tracks = switch (media) {
      Type1() => [PathUtils.videoNameType1],
      Type2(:final audio) => [
        PathUtils.videoNameType2,
        if (audio?.isNotEmpty == true) PathUtils.audioNameType2,
      ],
      _ => const <String>[],
    };
    final existing = <String>[];
    for (final name in tracks) {
      final file = File(path.join(index.parent.path, name));
      if (await file.exists() && await file.length() > 0) existing.add(name);
    }
    if (existing.isEmpty) return;

    final incompatible = UnsupportedError('已有缓存与当前媒体不匹配或来源无法确认，请删除该下载后重新缓存');
    final BiliDownloadMediaInfo previous;
    try {
      final saved =
          jsonDecode(await index.readAsString()) as Map<String, dynamic>;
      previous = saved.containsKey('segment_list')
          ? Type1.fromJson(saved)
          : Type2.fromJson(saved);
    } catch (_) {
      throw incompatible;
    }
    for (final file in existing) {
      final identity = _resumeIdentity(media, file);
      if (identity == null || _resumeIdentity(previous, file) != identity) {
        throw incompatible;
      }
    }
  }

  Future<void> _startDownload(
    BiliDownloadEntryInfo entry,
    int revision,
    CancelToken cancel,
  ) async {
    bool current() => _isCurrent(entry, revision);
    try {
      if (!await _prepare(
        downloadDanmaku(entry: entry, isCurrent: current),
        cancel,
      )) {
        return;
      }

      if (!current()) return;
      _updateCurStatus(DownloadStatus.getPlayUrl);

      final mediaFileInfo = await _prepare(resolveMedia(entry, cancel), cancel);
      if (!current()) return;

      final videoDir = Directory(path.join(entry.entryDirPath, entry.typeTag));
      if (!videoDir.existsSync()) {
        await videoDir.create(recursive: true);
      }

      if (!current()) return;
      final mediaJsonFile = File(path.join(videoDir.path, _indexFile));
      await _verifyResumeIdentity(mediaJsonFile, mediaFileInfo);
      if (!current()) return;
      // Keep the service lock until the index write finishes. A cancelled
      // attempt must not publish an index over the next attempt.
      await Future.wait([
        mediaJsonFile.writeAsString(jsonEncode(mediaFileInfo.toJson())),
        _prepare(_downloadCover(entry: entry, cancelToken: cancel), cancel),
      ]);

      if (!current()) {
        return;
      }

      switch (mediaFileInfo) {
        case Type1 mediaFileInfo:
          final first = mediaFileInfo.segmentList.first;
          _downloadManager = DownloadManager(
            url: first.url,
            path: path.join(videoDir.path, PathUtils.videoNameType1),
            onReceiveProgress: (progress, total) {
              if (current()) _onReceive(progress, total);
            },
            onDone: ([error]) {
              if (current()) _onDone(error);
            },
          );
          break;
        case Type2 mediaFileInfo:
          _downloadManager = DownloadManager(
            url: mediaFileInfo.video.first.baseUrl,
            path: path.join(videoDir.path, PathUtils.videoNameType2),
            onReceiveProgress: (progress, total) {
              if (current()) _onReceive(progress, total);
            },
            onDone: ([error]) {
              if (current()) _onDone(error);
            },
          );
          final audio = mediaFileInfo.audio;
          if (audio != null && audio.isNotEmpty) {
            _audioDownloadManager = DownloadManager(
              url: audio.first.baseUrl,
              path: path.join(videoDir.path, PathUtils.audioNameType2),
              onReceiveProgress: null,
              onDone: ([error]) {
                if (current()) _onAudioDone(error);
              },
            );
          }
          late final first = mediaFileInfo.video.first;
          entry.pageData
            ?..width = first.width
            ..height = first.height;
          entry.ep
            ?..width = first.width
            ..height = first.height;
          _updateBiliDownloadEntryJson(entry);
          break;
        default:
          break;
      }
      _startBackgroundTask();
    } catch (e) {
      if (!current() || cancel.isCancelled) return;
      _updateCurStatus(DownloadStatus.failPlayUrl);
      if (e is UnsupportedError) SmartDialog.showToast(e.message ?? '不支持该视频格式');
      if (kDebugMode) {
        debugPrint('get download url error: $e');
      }
    }
  }

  @protected
  Future<BiliDownloadMediaInfo> resolveMedia(
    BiliDownloadEntryInfo entry,
    CancelToken cancel,
  ) => DownloadHttp.getVideoUrl(
    entry: entry,
    ep: entry.ep,
    source: entry.source,
    pageData: entry.pageData,
    cancelToken: cancel,
  );

  Future<bool> _updateBiliDownloadEntryJson(
    BiliDownloadEntryInfo entry, {
    bool completed = false,
    bool Function()? isCurrent,
  }) {
    final entryJsonFile = File(path.join(entry.entryDirPath, _entryFile));
    final json = entry.toJson();
    if (completed) {
      json['is_completed'] = true;
      json['downloaded_bytes'] = entry.totalBytes;
    }
    final contents = jsonEncode(json);
    return _entryWriteLock.synchronized(() async {
      final temporary = File('${entryJsonFile.path}.tmp');
      try {
        if (!(isCurrent?.call() ?? true) ||
            !await Directory(entry.entryDirPath).exists()) {
          return false;
        }
        await temporary.writeAsString(contents, flush: true);
        if (!(isCurrent?.call() ?? true)) return false;
        await temporary.rename(entryJsonFile.path);
        return true;
      } on FileSystemException catch (error) {
        if (kDebugMode) debugPrint('write download entry: $error');
        return false;
      } finally {
        // A successful rename already moved the temporary file out of this path.
        await temporary.tryDel();
      }
    });
  }

  /// 启动鸿蒙长时任务，用于后台下载
  void _startBackgroundTask() {
    if (!OS.isHarmony) return;
    HarmonyChannel.startBackgroundTask();
  }

  /// 停止鸿蒙长时任务
  void _stopBackgroundTask() {
    if (!OS.isHarmony) return;
    HarmonyChannel.stopBackgroundTask();
  }

  void _onReceive(int progress, int total) {
    if (curDownload.value case final entry?) {
      entry
        ..downloadedBytes = progress
        ..status = DownloadStatus.downloading;
      if (total > 0 && total != entry.totalBytes) {
        unawaited(_updateBiliDownloadEntryJson(entry..totalBytes = total));
      }
      curDownload.refresh();
    }
  }

  void _onDone([Object? error]) {
    if (error != null) {
      _updateCurStatus(_downloadManager?.status ?? DownloadStatus.pause);
      _stopBackgroundTaskIfIdle();
      return;
    }

    final status = switch (_audioDownloadManager?.status) {
      DownloadStatus.downloading => DownloadStatus.audioDownloading,
      DownloadStatus.failDownload => DownloadStatus.failDownloadAudio,
      _ => _downloadManager?.status ?? DownloadStatus.pause,
    };
    if (status == DownloadStatus.completed) {
      unawaited(_completeDownload());
    } else {
      _updateCurStatus(status);
      if (curDownload.value case final entry?) {
        entry.downloadedBytes = entry.totalBytes;
        unawaited(_updateBiliDownloadEntryJson(entry));
      }
      _stopBackgroundTaskIfIdle();
    }
  }

  void _onAudioDone([Object? error]) {
    if (_downloadManager?.status == DownloadStatus.completed) {
      if (error == null) {
        unawaited(_completeDownload());
        return;
      }
      final status = _audioDownloadManager?.status ?? DownloadStatus.pause;
      _updateCurStatus(
        status == DownloadStatus.failDownload
            ? DownloadStatus.failDownloadAudio
            : status,
      );
    }
    _stopBackgroundTaskIfIdle();
  }

  void _stopBackgroundTaskIfIdle() {
    if (_downloadManager?.status.isDownloading != true &&
        _audioDownloadManager?.status.isDownloading != true) {
      _stopBackgroundTask();
    }
  }

  Future<void> _completeDownload() {
    final entry = curDownload.value;
    if (entry == null) return Future.value();
    final revision = _downloadRevision;
    bool current() => _isCurrent(entry, revision);
    return _lock.synchronized(() async {
      if (!current()) return;
      final saved = await _updateBiliDownloadEntryJson(
        entry,
        completed: true,
        isCurrent: current,
      );
      if (!current()) {
        // The atomic rename may have completed just as a pause superseded us.
        if (saved) await _updateBiliDownloadEntryJson(entry);
        return;
      }
      if (!saved) {
        // Keep the media and queue entry so retry can resume from disk.
        _updateCurStatus(DownloadStatus.failDownload);
        _stopBackgroundTask();
        return;
      }
      entry
        ..downloadedBytes = entry.totalBytes
        ..isCompleted = true
        ..status = DownloadStatus.completed;
      waitDownloadQueue.remove(entry);
      downloadList.insert(0, entry);
      _curCid = null;
      curDownload.value = null;
      _downloadManager = null;
      _audioDownloadManager = null;
      _stopBackgroundTask();
      flagNotifier.refresh();
      nextDownload();
    });
  }

  void nextDownload() {
    if (curDownload.value?.status.isDownloading == true) return;
    final next = waitDownloadQueue
        .where((entry) => entry.status == DownloadStatus.wait)
        .firstOrNull;
    if (next != null) unawaited(startDownload(next));
  }

  Future<void> deleteDownload({
    required BiliDownloadEntryInfo entry,
    bool removeList = false,
    bool removeQueue = false,
    bool refresh = true,
    bool downloadNext = true,
  }) async {
    if (removeList) {
      downloadList.remove(entry);
    }
    if (removeQueue || !entry.isCompleted) {
      waitDownloadQueue.remove(entry);
    }
    final deletingCurrent = curDownload.value?.cid == entry.cid;
    if (deletingCurrent) {
      await cancelDownload(isDelete: true, downloadNext: false);
    }
    await Directory(entry.entryDirPath).tryDel(recursive: true);
    // Removing an empty parent is safe even if a sibling appears meanwhile.
    await Directory(entry.pageDirPath).tryDel();
    if (deletingCurrent && downloadNext && curDownload.value == null) {
      nextDownload();
    }
    if (refresh) {
      flagNotifier.refresh();
    }
  }

  Future<void> deletePage({
    required String pageDirPath,
    bool refresh = true,
  }) async {
    final current = curDownload.value;
    final deletingCurrent = current?.pageDirPath == pageDirPath;
    waitDownloadQueue.removeWhere((e) => e.pageDirPath == pageDirPath);
    if (deletingCurrent) {
      await cancelDownload(isDelete: true, downloadNext: false);
    }
    await Directory(pageDirPath).tryDel(recursive: true);
    downloadList.removeWhere((e) => e.pageDirPath == pageDirPath);
    if (deletingCurrent && curDownload.value == null) nextDownload();
    if (refresh) {
      flagNotifier.refresh();
    }
  }

  Future<void> cancelDownload({
    required bool isDelete,
    bool downloadNext = true,
  }) {
    final revision = ++_downloadRevision;
    _prepareCancel?.cancel();
    _prepareCancel = null;
    return _lock.synchronized(() async {
      if (revision != _downloadRevision) return;
      await Future.wait([
        if (_downloadManager case final video?)
          video.cancel(isDelete: isDelete),
        if (_audioDownloadManager case final audio?)
          audio.cancel(isDelete: isDelete),
      ]);
      if (revision != _downloadRevision) return;
      _downloadManager = null;
      _audioDownloadManager = null;
      if (isDelete) {
        _curCid = null;
        curDownload.value = null;
      } else if (curDownload.value case final entry?) {
        _updateCurStatus(DownloadStatus.pause);
        await _updateBiliDownloadEntryJson(entry);
      }
      if (revision != _downloadRevision) return;
      _stopBackgroundTask();
      if (downloadNext) nextDownload();
    });
  }
}

typedef SetNotifier = Set<VoidCallback>;

extension SetNotifierExt on SetNotifier {
  void refresh() {
    for (final i in this) {
      i();
    }
  }
}
