import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/pages/video/shorts/media_cache.dart';
import 'package:PiliPlus/pages/video/shorts/preloader.dart';

void main() {
  test(
    'ready metadata is reused without waiting for byte preloading; contexts cannot mix',
    () async {
      final bytes = Completer<void>();
      CancelToken? token;
      var loads = 0;
      final preloader = NextVideoPreloader<String>(
        load: (id, cid, cancel) async {
          loads++;
          token = cancel;
          return '$id:$cid';
        },
        warm: (_, _) => bytes.future,
      );
      final pending = preloader.prepare('a', 10, 'account1-quality80');
      await Future<void>.delayed(Duration.zero);
      expect(preloader.cidFor('a', 'account1-quality80'), 10);
      expect(preloader.take('a', 10, 'account1-quality80'), 'a:10');
      expect(token!.isCancelled, isTrue);
      bytes.complete();
      await pending;
      await preloader.prepare('a', 10, 'account1-quality80');
      expect(preloader.take('a', 10, 'account2-quality120'), isNull);
      expect(loads, 2);
      preloader.dispose();
    },
  );
  test(
    'superseded request and disposed page cannot publish old prefetched data',
    () async {
      final first = Completer<String?>();
      final tokens = <CancelToken>[];
      final preloader = NextVideoPreloader<String>(
        load: (id, _, cancel) {
          tokens.add(cancel);
          return id == 'a' ? first.future : Future.value(id);
        },
        warm: (_, _) async {},
      );
      final old = preloader.prepare('a', 1, 'context');
      await preloader.prepare('b', 2, 'context');
      first.complete('old');
      await old;
      expect(tokens.first.isCancelled, isTrue);
      expect(preloader.take('b', 2, 'context'), 'b');
      preloader.dispose();
      await preloader.prepare('c', 3, 'context');
      expect(tokens.length, 2);
    },
  );

  test(
    'buffering cancels speculative traffic and recovery reuses metadata',
    () async {
      var loads = 0, warms = 0;
      final tokens = <CancelToken>[];
      final preloader = NextVideoPreloader<String>(
        load: (id, _, _) async {
          loads++;
          return id;
        },
        warm: (_, cancel) async {
          warms++;
          tokens.add(cancel);
          if (warms == 1) await cancel.whenCancel;
        },
      );
      final first = preloader.prepare('next', 3, 'context');
      await Future<void>.delayed(Duration.zero);
      preloader.suspend();
      await first;
      expect(tokens.first.isCancelled, isTrue);
      await preloader.prepare('next', 3, 'context');
      expect(loads, 1);
      expect(warms, 2);
      expect(preloader.take('next', 3, 'context'), 'next');
      preloader.dispose();
    },
  );

  group('real HTTP prefix reuse', () {
    late HttpServer origin;
    late Dio originClient, decoder;
    late ShortMediaCache cache;
    late String url;
    final ranges = <String>[];
    final bytes = List.generate(4096, (i) => i % 251);
    var badRange = false;
    setUp(() async {
      ranges.clear();
      badRange = false;
      origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      origin.listen((request) async {
        final raw = request.headers.value('range')!;
        ranges.add(raw);
        final match = RegExp(r'bytes=(\d+)-(\d+)').firstMatch(raw)!;
        final start = int.parse(match[1]!);
        final end = int.parse(match[2]!).clamp(0, bytes.length - 1);
        request.response.statusCode = badRange ? 200 : 206;
        request.response.headers.set('content-type', 'video/mp4');
        request.response.headers.set(
          'content-range',
          'bytes $start-$end/${bytes.length}',
        );
        request.response.headers.set('etag', 'stable-file');
        request.response.contentLength = end - start + 1;
        request.response.add(bytes.sublist(start, end + 1));
        try {
          await request.response.close();
        } catch (_) {}
      });
      url = 'http://127.0.0.1:${origin.port}/media';
      originClient = Dio();
      decoder = Dio(BaseOptions(responseType: ResponseType.bytes));
      cache = ShortMediaCache(originClient);
    });
    tearDown(() async {
      await cache.dispose();
      originClient.close(force: true);
      decoder.close(force: true);
      await origin.close(force: true);
    });
    test(
      'cached head and stitched tail equal original bytes without fetching the head twice',
      () async {
        await cache.warm(url, 1024, CancelToken());
        expect(cache.bytesHeld, 1024);
        final local = cache.sourceFor(url);
        expect(local, isNot(url));
        final head = await decoder.get<List<int>>(
          local,
          options: Options(headers: {'Range': 'bytes=0-255'}),
        );
        expect(head.statusCode, 206);
        expect(head.data, bytes.sublist(0, 256));
        expect(ranges, ['bytes=0-1023']);
        final cross = await decoder.get<List<int>>(
          local,
          options: Options(headers: {'Range': 'bytes=900-1300'}),
        );
        expect(cross.data, bytes.sublist(900, 1301));
        expect(ranges.last, 'bytes=1024-1300');
        final all = await decoder.get<List<int>>(local);
        expect(all.statusCode, 200);
        expect(all.data, bytes);
        expect(ranges.last, 'bytes=1024-4095');
        final tail = await decoder.get<List<int>>(
          local,
          options: Options(headers: {'Range': 'bytes=-16'}),
        );
        expect(tail.data, bytes.sublist(4080));
      },
    );
    test(
      'HEAD, invalid ranges, opaque URLs and eviction are bounded and predictable',
      () async {
        await cache.warm(url, 1024, CancelToken());
        final local = cache.sourceFor(url);
        final head = await decoder.head(local);
        expect(head.headers.value('content-length'), '4096');
        expect(ranges.length, 1);
        for (final range in ['bytes=9999-', 'bytes=4-2', 'bytes=0-1,3-4']) {
          final result = await decoder.get(
            local,
            options: Options(
              headers: {'Range': range},
              validateStatus: (_) => true,
            ),
          );
          expect(result.statusCode, 416);
        }
        final bad = await decoder.get(
          Uri.parse(local).replace(path: '/guess').toString(),
          options: Options(validateStatus: (_) => true),
        );
        expect(bad.statusCode, 404);
        cache.retain({});
        expect(cache.bytesHeld, 0);
        expect(cache.sourceFor(url), url);
        final removed = await decoder.get(
          local,
          options: Options(validateStatus: (_) => true),
        );
        expect(removed.statusCode, 404);
      },
    );
    test(
      'cancelled warmup never exposes partial bytes and rejected range falls back directly',
      () async {
        final token = CancelToken()..cancel();
        await cache.warm(url, 1024, token);
        expect(cache.sourceFor(url), url);
        badRange = true;
        // 200 with larger total is not a safe partial cached file.
        await cache.warm(url, 512, CancelToken());
        expect(cache.entriesHeld, 0);
      },
    );
  });
}
