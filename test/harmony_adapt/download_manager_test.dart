import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/services/download/download_manager.dart';
import 'package:PiliPlus/models_new/download/bili_download_entry_info.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final Future<ResponseBody> Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) => respond(options);
  @override
  void close({bool force = false}) {}
}

void main() {
  late Directory root;
  late Dio client;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('download-manager-');
    client = Dio();
  });
  tearDown(() async {
    client.close(force: true);
    await root.delete(recursive: true);
  });
  test(
    'real HTTP resumes a partial file and stops a slow response on pause',
    () async {
      final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final release = Completer<void>();
      final received = Completer<void>();
      final file = File('${root.path}/real-clip');
      await file.writeAsBytes([1, 2]);
      origin.listen((request) async {
        expect(request.headers.value('range'), 'bytes=2-');
        request.response.bufferOutput = false;
        request.response.statusCode = 206;
        request.response.headers.set('Content-Range', 'bytes 2-5/6');
        request.response.contentLength = 4;
        request.response.add([3, 4]);
        await request.response.flush();
        await release.future;
        try {
          request.response.add([5, 6]);
          await request.response.close();
        } catch (_) {}
      });
      client.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            options.path = options.path.replaceFirst('https://', 'http://');
            handler.next(options);
          },
        ),
      );
      final manager = DownloadManager(
        url: 'http://127.0.0.1:${origin.port}/clip',
        path: file.path,
        client: client,
        onReceiveProgress: (n, _) {
          if (n >= 4 && !received.isCompleted) received.complete();
        },
        onDone: ([error]) => expect(error, isNotNull),
      );
      await received.future.timeout(const Duration(seconds: 5));
      await manager.cancel(isDelete: false).timeout(const Duration(seconds: 2));
      expect(manager.status, DownloadStatus.pause);
      expect(await file.readAsBytes(), [1, 2, 3, 4]);
      release.complete();
      await origin.close(force: true);
    },
  );
  test(
    'server ignoring Range restarts instead of corrupting resumed media',
    () async {
      final file = File('${root.path}/clip');
      await file.writeAsBytes([1, 2]);
      client.httpClientAdapter = _Adapter((request) async {
        expect(request.headers['range'], 'bytes=2-');
        return ResponseBody.fromBytes(
          [1, 2, 3, 4],
          200,
          headers: {
            'content-length': ['4'],
          },
        );
      });
      Object? error;
      final manager = DownloadManager(
        url: 'https://cdn.test/clip',
        path: file.path,
        onReceiveProgress: null,
        onDone: ([e]) => error = e,
        client: client,
      );
      await manager.task;
      expect(error, isNull);
      expect(manager.status, DownloadStatus.completed);
      expect(await file.readAsBytes(), [1, 2, 3, 4]);
    },
  );
  test('206 validates range offset and resumes valid partial data', () async {
    final file = File('${root.path}/clip');
    await file.writeAsBytes([1, 2]);
    client.httpClientAdapter = _Adapter(
      (_) async => ResponseBody.fromBytes(
        [3, 4],
        206,
        headers: {
          'content-length': ['2'],
          'content-range': ['bytes 2-3/4'],
        },
      ),
    );
    final progress = <(int, int)>[];
    final manager = DownloadManager(
      url: 'https://cdn.test/clip',
      path: file.path,
      onReceiveProgress: (a, b) => progress.add((a, b)),
      onDone: ([e]) => expect(e, isNull),
      client: client,
    );
    await manager.task;
    expect(await file.readAsBytes(), [1, 2, 3, 4]);
    expect(progress.first, (2, 4));
    expect(progress.last, (4, 4));
  });
  test(
    'mismatched 206 and oversized 416 do not mark corrupt data complete',
    () async {
      for (final status in [206, 416]) {
        final file = File('${root.path}/clip$status');
        await file.writeAsBytes([1, 2, 3]);
        client.httpClientAdapter = _Adapter(
          (_) async => ResponseBody.fromBytes(
            [],
            status,
            headers: {
              'content-length': ['0'],
              'content-range': [status == 206 ? 'bytes 1-2/3' : 'bytes */2'],
            },
          ),
        );
        Object? error;
        final manager = DownloadManager(
          url: 'https://cdn.test/clip',
          path: file.path,
          onReceiveProgress: null,
          onDone: ([e]) => error = e,
          client: client,
        );
        await manager.task;
        expect(error, isNotNull);
        expect(manager.status, DownloadStatus.failDownload);
        expect(await file.readAsBytes(), [1, 2, 3]);
      }
    },
  );
  test(
    '416 completes only when local size equals the declared full size',
    () async {
      final file = File('${root.path}/clip');
      await file.writeAsBytes([1, 2, 3]);
      client.httpClientAdapter = _Adapter(
        (_) async => ResponseBody.fromBytes(
          [],
          416,
          headers: {
            'content-range': ['bytes */3'],
          },
        ),
      );
      var done = 0;
      final manager = DownloadManager(
        url: 'https://cdn.test/clip',
        path: file.path,
        onReceiveProgress: null,
        onDone: ([e]) {
          expect(e, isNull);
          done++;
        },
        client: client,
      );
      await manager.task;
      expect(done, 1);
      expect(manager.status, DownloadStatus.completed);
      expect(await file.readAsBytes(), [1, 2, 3]);
    },
  );
  test(
    'pause interrupts a stream waiting for more bytes and preserves partial file',
    () async {
      final file = File('${root.path}/clip');
      final input = StreamController<Uint8List>();
      final received = Completer<void>();
      client.httpClientAdapter = _Adapter(
        (_) async => ResponseBody(
          input.stream,
          200,
          headers: {
            'content-length': ['100'],
          },
        ),
      );
      Object? error;
      final manager = DownloadManager(
        url: 'https://cdn.test/clip',
        path: file.path,
        onReceiveProgress: (n, _) {
          if (n > 0 && !received.isCompleted) received.complete();
        },
        onDone: ([e]) => error = e,
        client: client,
      );
      input.add(Uint8List.fromList([1, 2, 3]));
      await received.future;
      await manager.cancel(isDelete: false).timeout(const Duration(seconds: 2));
      expect(manager.status, DownloadStatus.pause);
      expect(error, isNotNull);
      expect(await file.readAsBytes(), [1, 2, 3]);
      await input.close();
    },
  );
  test('network failure keeps partial data instead of deleting it', () async {
    final file = File('${root.path}/clip');
    await file.writeAsBytes([1, 2]);
    client.httpClientAdapter = _Adapter(
      (request) async => throw DioException.connectionError(
        requestOptions: request,
        reason: 'offline',
      ),
    );
    final manager = DownloadManager(
      url: 'https://cdn.test/clip',
      path: file.path,
      onReceiveProgress: null,
      onDone: ([e]) => expect(e, isNotNull),
      client: client,
    );
    await manager.task;
    expect(await file.readAsBytes(), [1, 2]);
    expect(manager.status, DownloadStatus.failDownload);
  });
  test('truncated response never becomes a completed download', () async {
    final file = File('${root.path}/clip');
    client.httpClientAdapter = _Adapter(
      (_) async => ResponseBody.fromBytes(
        [1, 2],
        200,
        headers: {
          'content-length': ['4'],
        },
      ),
    );
    final manager = DownloadManager(
      url: 'https://cdn.test/clip',
      path: file.path,
      onReceiveProgress: null,
      onDone: ([e]) => expect(e, isNotNull),
      client: client,
    );
    await manager.task;
    expect(manager.status, DownloadStatus.failDownload);
    expect(await file.readAsBytes(), [1, 2]);
  });
  test(
    'real HTTP partial or unknown totals never enter the completed list',
    () async {
      final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      origin.listen((request) async {
        expect(request.headers.value('range'), 'bytes=2-');
        request.response.statusCode = 206;
        final total = request.uri.path == '/known' ? '6' : '*';
        request.response.headers.set('Content-Range', 'bytes 2-3/$total');
        request.response.contentLength = 2;
        request.response.add([3, 4]);
        await request.response.close();
      });
      client.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            options.path = options.path.replaceFirst('https://', 'http://');
            handler.next(options);
          },
        ),
      );
      try {
        for (final mode in ['known', 'unknown']) {
          final file = File('${root.path}/$mode');
          await file.writeAsBytes([1, 2]);
          final manager = DownloadManager(
            url: 'http://127.0.0.1:${origin.port}/$mode',
            path: file.path,
            client: client,
            onReceiveProgress: null,
            onDone: ([e]) => expect(e, isNotNull),
          );
          await manager.task.timeout(const Duration(seconds: 5));
          expect(manager.status, DownloadStatus.failDownload);
          expect(
            await file.readAsBytes(),
            mode == 'known' ? [1, 2, 3, 4] : [1, 2],
          );
        }
      } finally {
        await origin.close(force: true);
      }
    },
  );
  test(
    'invalid range aborts an unfinished response instead of buffering its body',
    () async {
      final file = File('${root.path}/rejected');
      await file.writeAsBytes([1, 2]);
      final body = StreamController<Uint8List>();
      var released = false;
      client.httpClientAdapter = _Adapter(
        (_) async => ResponseBody(
          body.stream,
          206,
          headers: {
            'content-range': ['bytes 1-999999/1000000'],
            'content-length': ['999999'],
          },
          onClose: () => released = true,
        ),
      );
      final manager = DownloadManager(
        url: 'https://cdn.test/rejected',
        path: file.path,
        onReceiveProgress: null,
        onDone: ([e]) => expect(e, isNotNull),
        client: client,
      );
      await manager.task.timeout(const Duration(seconds: 2));
      await Future<void>.delayed(Duration.zero);
      expect(released, isTrue);
      expect(await file.readAsBytes(), [1, 2]);
      await body.close();
    },
  );
}
