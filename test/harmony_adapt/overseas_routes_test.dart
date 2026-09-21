import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/utils/media_route_resolver.dart';
import 'package:PiliPlus/models/video/play/url.dart';
import 'package:PiliPlus/models/common/video/video_quality.dart';

const original =
    'https://upos-sz-mirrorali.bilivideo.com/upgcxcode/01/02/v.m4s?deadline=123&sig=a%2Fb%2Bc&token=x%3D';

void main() {
  test(
    'only approved media paths are rewritten and signed queries survive',
    () {
      final choices = overseasMediaCandidates([original, original]);
      expect(choices.length, 4);
      expect(choices.map((u) => u.query).toSet(), {Uri.parse(original).query});
      expect(choices.take(3).every((u) => u.scheme == 'https'), isTrue);
      for (final unknown in [
        'file:///upgcxcode/a',
        'edl://a',
        'https://evil.com/upgcxcode/a',
        'https://bilivideo.com.evil.com/upgcxcode/a',
      ]) {
        expect(overseasMediaCandidates([unknown]), isEmpty);
      }
      expect(
        overseasMediaCandidates([
          'https://x.bilivideo.com/v1/resource/a',
        ]).length,
        1,
      );
      expect(overseasMediaCandidates(['$original&os=mcdn']).length, 1);
    },
  );
  test(
    'fast valid overseas response wins and cancels losing transfers',
    () async {
      final tokens = <CancelToken>[];
      final resolver = MediaRouteResolver(
        probe: (uri, token) async {
          tokens.add(token);
          if (uri.host == overseasMediaHosts[1]) return true;
          await token.whenCancel;
          return false;
        },
      );
      final selected = await resolver.resolve([original], fallback: original);
      expect(Uri.parse(selected).host, overseasMediaHosts[1]);
      expect(tokens.every((e) => e.isCancelled), isTrue);
      final second = await resolver.resolve([original], fallback: original);
      expect(Uri.parse(second).host, overseasMediaHosts[1]);
      resolver.reset();
    },
  );
  test(
    'unresponsive routes meet deadline and fall back to server URL',
    () async {
      final tokens = <CancelToken>[];
      final resolver = MediaRouteResolver(
        budget: const Duration(milliseconds: 35),
        headStart: Duration.zero,
        probe: (uri, token) async {
          tokens.add(token);
          await token.whenCancel;
          return false;
        },
      );
      final watch = Stopwatch()..start();
      expect(await resolver.resolve([original], fallback: original), original);
      expect(watch.elapsedMilliseconds, lessThan(500));
      expect(tokens.every((e) => e.isCancelled), isTrue);
    },
  );
  test(
    'failed hosts are skipped temporarily, reset cancels pending work',
    () async {
      var clock = DateTime(2026);
      final seen = <String>[];
      final resolver = MediaRouteResolver(
        now: () => clock,
        headStart: Duration.zero,
        probe: (uri, _) async {
          seen.add(uri.host);
          return true;
        },
      );
      resolver.reject('https://${overseasMediaHosts[0]}/v');
      await resolver.resolve([original], fallback: original);
      expect(seen, isNot(contains(overseasMediaHosts[0])));
      clock = clock.add(const Duration(minutes: 6));
      seen.clear();
      await resolver.resolve([original], fallback: original);
      expect(seen, contains(overseasMediaHosts[0]));
      final pendingResolver = MediaRouteResolver(
        probe: (_, token) async {
          await token.whenCancel;
          return false;
        },
      );
      final pending = pendingResolver.resolve([original], fallback: original);
      pendingResolver.reset();
      expect(await pending, original);
    },
  );
  test(
    'requested quality is retained; only optional supplement can be deferred',
    () {
      final data = PlayUrlModel(
        acceptQuality: [120, 80, 64],
        dash: Dash(
          video: [
            VideoItem(id: 120, quality: VideoQuality.fromCode(120)),
            VideoItem(id: 80, quality: VideoQuality.fromCode(80)),
          ],
        ),
      );
      expect(data.canDeferQualitySupplement(80), isTrue);
      expect(data.canDeferQualitySupplement(64), isFalse);
      expect(data.canDeferQualitySupplement(127), isTrue);
      expect(PlayUrlModel().canDeferQualitySupplement(80), isFalse);
    },
  );
  test(
    'real HTTP range probe rejects errors/HTML/redirects and caps consumption',
    () async {
      // Plain unit test: local HTTP fixture only, no account or public CDN needed.
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final seenRange = <String?>[];
      final subscription = server.listen((request) async {
        seenRange.add(request.headers.value('range'));
        final response = request.response;
        switch (request.uri.path) {
          case '/forbidden':
            response.statusCode = 403;
          case '/html':
            response.headers.contentType = ContentType.html;
          case '/redirect':
            response.statusCode = 302;
            response.headers.set('location', '/ok');
          default:
            response.statusCode = 206;
            response.headers.set('content-type', 'video/mp4');
            response.headers.set('content-range', 'bytes 0-16383/100000');
        }
        response.add(List.filled(16384, 1));
        await response.close();
      });
      final dio = Dio();
      try {
        for (final path in ['/ok', '/forbidden', '/html', '/redirect']) {
          final token = CancelToken();
          final ok = await probeMediaRange(
            dio,
            Uri.parse('http://127.0.0.1:${server.port}$path'),
            token,
          );
          expect(ok, path == '/ok');
          token.cancel();
        }
        expect(seenRange, List.filled(4, 'bytes=0-16383'));
      } finally {
        dio.close(force: true);
        await subscription.cancel();
        await server.close(force: true);
      }
    },
  );
}
