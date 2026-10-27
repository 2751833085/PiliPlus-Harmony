import 'dart:async';
import 'dart:io';

import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/models_new/download/bili_download_entry_info.dart';
import 'package:PiliPlus/utils/extension/string_ext.dart';
import 'package:dio/dio.dart';

class DownloadManager {
  final String url;
  final String path;
  final void Function(int, int)? onReceiveProgress;
  final void Function([Object? error]) onDone;
  final Dio? _client;

  DownloadStatus _status = DownloadStatus.downloading;
  DownloadStatus get status => _status;
  final _cancelToken = CancelToken();
  late Future<void> task;

  DownloadManager({
    required this.url,
    required this.path,
    required this.onReceiveProgress,
    required this.onDone,
    Dio? client,
  }) : _client = client {
    task = _start();
  }

  void _checkCancelled() {
    final error = _cancelToken.cancelError;
    if (error != null) throw error;
  }

  Future<void> _start() async {
    IOSink? sink;
    Object? error;
    try {
      final file = File(path);
      var received = await file.exists() ? await file.length() : 0;
      _checkCancelled();
      final response = await (_client ?? Request.http11Dio).get<ResponseBody>(
        url.http2https,
        options: Options(
          headers: {'range': 'bytes=$received-'},
          responseType: ResponseType.stream,
          validateStatus: (status) =>
              status == 200 || status == 206 || status == 416,
        ),
        cancelToken: _cancelToken,
      );
      _checkCancelled();
      final data = response.data!;
      final range = response.headers.value('content-range');
      if (response.statusCode == 416) {
        final total = int.tryParse(
          RegExp(r'^bytes \*/(\d+)$').firstMatch(range ?? '')?.group(1) ?? '',
        );
        // A 416 can mean a stale/oversized partial, not necessarily completion.
        if (total == null || total <= 0 || received != total) {
          throw StateError(
            'Download range is not satisfiable for the local file',
          );
        }
        onReceiveProgress?.call(received, total);
        _status = DownloadStatus.completed;
        // The 416 body is not media and is never consumed by the file sink.
        if (!_cancelToken.isCancelled) _cancelToken.cancel();
        onDone();
        return;
      }
      int? expectedEnd;
      var total = 0;
      if (response.statusCode == 206) {
        final match = RegExp(
          r'^bytes (\d+)-(\d+)/(\d+|\*)$',
        ).firstMatch(range ?? '');
        final start = int.tryParse(match?.group(1) ?? '');
        final end = int.tryParse(match?.group(2) ?? '');
        total = int.tryParse(match?.group(3) ?? '') ?? 0;
        if (start != received ||
            total <= 0 ||
            end == null ||
            end < received ||
            (total > 0 && end >= total) ||
            (data.contentLength >= 0 &&
                data.contentLength != end - received + 1)) {
          throw StateError(
            'Download server returned a mismatched partial range',
          );
        }
        expectedEnd = end + 1;
      } else {
        // Servers may ignore Range. Start over instead of appending a full copy.
        received = 0;
        if (data.contentLength >= 0) {
          total = data.contentLength;
          expectedEnd = total;
        }
      }
      _checkCancelled();
      await file.parent.create(recursive: true);
      sink = file.openWrite(
        mode: received == 0 ? FileMode.writeOnly : FileMode.writeOnlyAppend,
      );
      onReceiveProgress?.call(received, total);
      int? last;
      // addStream propagates file-write backpressure to the network stream.
      await sink.addStream(
        _cancellable(data.stream).map((chunk) {
          _checkCancelled();
          received += chunk.length;
          final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          if (last != now) {
            last = now;
            onReceiveProgress?.call(received, total);
          }
          return chunk;
        }),
      );
      await sink.close();
      sink = null;
      _checkCancelled();
      if ((expectedEnd != null && received != expectedEnd) ||
          (total > 0 && received != total)) {
        throw StateError(
          'Download ended before the expected byte range completed',
        );
      }
      onReceiveProgress?.call(received, total == 0 ? received : total);
      _status = DownloadStatus.completed;
    } catch (e) {
      error = e;
      // Header validation or disk failures must also stop the unread network
      // body; otherwise Dio can keep buffering an entire rejected media file.
      if (!_cancelToken.isCancelled) _cancelToken.cancel();
      // Keep valid partial data on a network failure or pause for a later resume.
      if (_status == DownloadStatus.downloading)
        _status = DownloadStatus.failDownload;
    } finally {
      try {
        await sink?.close();
      } catch (e) {
        error ??= e;
        if (_status == DownloadStatus.downloading)
          _status = DownloadStatus.failDownload;
      }
    }
    onDone(error);
  }

  Stream<List<int>> _cancellable(Stream<List<int>> input) {
    StreamSubscription<List<int>>? subscription;
    late StreamController<List<int>> output;
    output = StreamController<List<int>>(
      sync: true,
      onListen: () {
        subscription = input.listen(
          output.add,
          onError: output.addError,
          onDone: output.close,
        );
      },
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: () => subscription?.cancel(),
    );
    _cancelToken.whenCancel.then((e) async {
      if (!output.isClosed) {
        output.addError(e);
        await output.close();
      }
      await subscription?.cancel();
    });
    return output.stream;
  }

  Future<void> cancel({required bool isDelete}) {
    if (!isDelete && _status == DownloadStatus.downloading)
      _status = DownloadStatus.pause;
    if (!_cancelToken.isCancelled) _cancelToken.cancel();
    return task;
  }
}
