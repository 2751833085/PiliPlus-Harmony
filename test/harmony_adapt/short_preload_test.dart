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
      expect(await preloader.take('a', 10, 'account1-quality80'), 'a:10');
      expect(token!.isCancelled, isFalse);
      bytes.complete();
      await pending;
      await preloader.prepare('a', 10, 'account1-quality80');
      expect(await preloader.take('a', 10, 'account2-quality120'), isNull);
      expect(loads, 1);
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
      preloader.retain({'b'}, 'context');
      await preloader.prepare('b', 2, 'context');
      first.complete('old');
      await old;
      expect(tokens.first.isCancelled, isTrue);
      expect(await preloader.take('b', 2, 'context'), 'b');
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
      expect(await preloader.take('next', 3, 'context'), 'next');
      preloader.dispose();
    },
  );

  test(
    'rapid target changes retain three prefetched items and join in-flight metadata once',
    () async {
      final api = Completer<String?>();
      final media = Completer<void>();
      final calls = <String>[];
      final tokens = <String, CancelToken>{};
      final preloader = NextVideoPreloader<String>(
        load: (id, _, cancel) {
          calls.add(id);
          tokens[id] = cancel;
          return id == 'b' ? api.future : Future.value(id);
        },
        warm: (_, _) => media.future,
      );
      final jobs = [
        preloader.prepare('b', 2, 'ctx'),
        preloader.prepare('c', 3, 'ctx'),
        preloader.prepare('d', 4, 'ctx'),
      ];
      final foreground = preloader.take('b', 2, 'ctx');
      api.complete('b');
      expect(await foreground, 'b');
      expect(await preloader.take('d', 4, 'ctx'), 'd');
      expect(calls, ['b', 'c', 'd']);
      expect(tokens.values.every((t) => !t.isCancelled), true);
      preloader.retain({'c', 'd'}, 'ctx');
      expect(tokens['b']!.isCancelled, true);
      expect(tokens['c']!.isCancelled, false);
      expect(await preloader.take('c', 3, 'different-account'), isNull);
      media.complete();
      await Future.wait(jobs);
      preloader.dispose();
    },
  );
  test(
    'foreground waiter is released when its window is invalidated',
    () async {
      final delayed = Completer<String?>();
      final preloader = NextVideoPreloader<String>(
        load: (_, _, _) => delayed.future,
        warm: (_, _) async {},
      );
      final job = preloader.prepare('a', 1, 'old');
      final waiter = preloader.take('a', 1, 'old');
      preloader.retain({'a'}, 'new');
      expect(await waiter, isNull);
      delayed.complete('expired');
      await job;
      expect(await preloader.take('a', 1, 'old'), isNull);
      preloader.dispose();
    },
  );
  test(
    'decoder joins pending warmup before its tail finishes; cached bytes are flushed immediately',
    () async {
      final tail = Completer<void>();
      final requested = Completer<void>();
      final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final data = List.generate(256 * 1024, (i) => i % 251);
      var calls = 0;
      origin.listen((request) async {
        calls++;
        request.response.statusCode = 206;
        request.response.headers.set('Content-Type', 'video/mp4');
        request.response.headers.set('Content-Range', 'bytes 0-262143/262144');
        request.response.contentLength = data.length;
        request.response.add(data.sublist(0, 65536));
        await request.response.flush();
        requested.complete();
        await tail.future;
        request.response.add(data.sublist(65536));
        try {
          await request.response.close();
        } catch (_) {}
      });
      final client = Dio();
      final decoder = Dio(BaseOptions(responseType: ResponseType.bytes));
      final cache = ShortMediaCache(client);
      final url = 'http://127.0.0.1:${origin.port}/clip';
      final warming = cache.warm(url, data.length, CancelToken());
      final source = await cache.playbackSourceFor(url);
      expect(source, isNot(url));
      await requested.future;
      final head = await decoder.get<List<int>>(
        source,
        options: Options(headers: {'Range': 'bytes=0-31'}),
      );
      expect(head.data, data.sublist(0, 32));
      expect(tail.isCompleted, false);
      expect(calls, 1);
      tail.complete();
      await warming;
      expect(cache.bytesHeld, data.length);
      await cache.dispose();
      client.close(force: true);
      decoder.close(force: true);
      await origin.close(force: true);
    },
  );

  test(
    'a decoder already joining a failed warmup falls back to the origin',
    () async {
      final requested = Completer<void>();
      final release = Completer<void>();
      final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final bytes = List.generate(1024, (i) => i % 251);
      var calls = 0;
      origin.listen((request) async {
        if (++calls == 1) {
          requested.complete();
          await release.future;
          request.response.statusCode = 503;
        } else {
          request.response.headers.set('Content-Type', 'video/mp4');
          final range = request.headers.value('range');
          final data = range == 'bytes=100-127'
              ? bytes.sublist(100, 128)
              : bytes;
          if (range == 'bytes=100-127') {
            request.response.statusCode = 206;
            request.response.headers.set('Content-Range', 'bytes 100-127/1024');
          }
          request.response.contentLength = data.length;
          request.response.add(data);
        }
        await request.response.close();
      });
      final client = Dio();
      final decoder = Dio(BaseOptions(responseType: ResponseType.bytes));
      final cache = ShortMediaCache(client);
      addTearDown(() async {
        await cache.dispose();
        client.close(force: true);
        decoder.close(force: true);
        await origin.close(force: true);
      });
      final url = 'http://127.0.0.1:${origin.port}/clip';
      final warming = cache.warm(url, bytes.length, CancelToken());
      final local = await cache.playbackSourceFor(url);
      expect(local, isNot(url));
      await requested.future;
      release.complete();
      await warming;
      final redirect = await decoder.head(
        local,
        options: Options(followRedirects: false, validateStatus: (_) => true),
      );
      expect(redirect.statusCode, 307);
      expect(redirect.headers.value('location'), url);
      expect(redirect.headers.value('cache-control'), 'no-store');
      final result = await decoder.get<List<int>>(local);
      expect(result.data, bytes);
      expect(calls, 2);
      final ranged = await decoder.get<List<int>>(
        local,
        options: Options(headers: {'Range': 'bytes=100-127'}),
      );
      expect(ranged.statusCode, 206);
      expect(ranged.data, bytes.sublist(100, 128));
      expect(cache.sourceFor(url), url);
      // Retrying the same source keeps the address already held by the decoder.
      await cache.warm(url, bytes.length, CancelToken());
      expect(cache.sourceFor(url), local);
      expect(cache.bytesHeld, bytes.length);
      cache.retain({});
      final evicted = await decoder.get(
        local,
        options: Options(validateStatus: (_) => true),
      );
      expect(evicted.statusCode, 404);
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
      'concurrent media warmups respect the stream cap and retain the current stream',
      () async {
        await Future.wait([
          for (var i = 0; i < 12; i++)
            cache.warm('$url?$i', 1024, CancelToken()),
        ]);
        expect(cache.entriesHeld, ShortMediaCache.maxStreams);
        expect(
          cache.bytesHeld,
          lessThanOrEqualTo(
            ShortMediaCache.maxStreams * ShortMediaCache.maxPrefixBytes,
          ),
        );
        final current = cache.sourceFor('$url?0');
        cache.retain({'$url?0', '$url?1'});
        expect(cache.entriesHeld, 2);
        final head = await decoder.get<List<int>>(
          current,
          options: Options(headers: {'Range': 'bytes=0-15'}),
        );
        expect(head.data, bytes.sublist(0, 16));
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
