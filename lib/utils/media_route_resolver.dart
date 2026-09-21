import 'dart:async';
import 'package:dio/dio.dart';

const overseasMediaHosts = [
  'upos-hz-mirrorakam.akamaized.net',
  'upos-sz-mirroraliov.bilivideo.com',
  'upos-sz-mirrorcosov.bilivideo.com',
];

bool _biliMediaHost(String host) =>
    host.endsWith('.bilivideo.com') ||
    host.endsWith('.bilivideo.cn') ||
    host.endsWith('.bilivideo.net') ||
    overseasMediaHosts.contains(host);

/// Rewrite only Bilibili's transferable media paths. The signed query remains
/// byte-for-byte intact; unknown hosts, local files and playlists are untouched.
List<Uri> overseasMediaCandidates(Iterable<String> urls) {
  final originals = urls
      .map(Uri.tryParse)
      .whereType<Uri>()
      .where(
        (u) =>
            (u.scheme == 'https' || u.scheme == 'http') &&
            _biliMediaHost(u.host) &&
            u.userInfo.isEmpty,
      )
      .toList();
  final transferable = originals
      .where(
        (u) =>
            u.path.startsWith('/upgcxcode/') &&
            u.queryParameters['os'] != 'mcdn',
      )
      .firstOrNull;
  return <Uri>{
    if (transferable != null)
      for (final host in overseasMediaHosts)
        transferable.replace(scheme: 'https', host: host, port: 443),
    ...originals.take(2),
  }.toList();
}

typedef MediaProbe = Future<bool> Function(Uri uri, CancelToken cancel);

/// Bounded small-range races; no full-file speed test or persistent signed URL.
/// Video and audio use separate instances so one stream cannot mask a bad route
/// for the other. A recent winner gets a head start, never blind long-term trust.
class MediaRouteResolver {
  MediaRouteResolver({
    required this.probe,
    this.budget = const Duration(milliseconds: 1600),
    this.headStart = const Duration(milliseconds: 120),
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  final MediaProbe probe;
  final Duration budget, headStart;
  final DateTime Function() now;
  int _generation = 0;
  String? _preferredHost;
  DateTime? _preferredUntil;
  final Map<String, DateTime> _failed = {};
  final Set<CancelToken> _active = {};

  void reset() {
    _generation++;
    _preferredHost = null;
    _preferredUntil = null;
    _failed.clear();
    for (final token in _active.toList()) {
      token.cancel('route invalidated');
    }
  }

  void reject(String? url) {
    final host = url == null ? null : Uri.tryParse(url)?.host;
    if (host == null || host.isEmpty) return;
    _failed[host] = now().add(const Duration(minutes: 1));
    if (_preferredHost == host) _preferredHost = null;
  }

  Future<String> resolve(
    Iterable<String> urls, {
    required String fallback,
  }) async {
    final generation = _generation;
    final candidates = overseasMediaCandidates(urls);
    if (candidates.isEmpty) return fallback;
    _failed.removeWhere((_, until) => !until.isAfter(now()));
    final usable = candidates
        .where((u) => !_failed.containsKey(u.host))
        .toList();
    if (usable.isEmpty) return fallback;
    final preferred = _preferredUntil?.isAfter(now()) == true
        ? _preferredHost
        : null;
    final done = Completer<Uri?>();
    final cancel = CancelToken();
    _active.add(cancel);
    cancel.whenCancel.then((_) {
      if (!done.isCompleted) done.complete(null);
    });
    final deadline = Timer(budget, () {
      if (!done.isCompleted) done.complete(null);
    });
    var remaining = usable.length;
    Future<void> run(Uri uri) async {
      // Overseas routes start first; official originals join quickly when none
      // respond. A cached winner avoids spending extra bandwidth unnecessarily.
      final delay = preferred != null
          ? uri.host != preferred
          : !overseasMediaHosts.contains(uri.host);
      if (delay) await Future<void>.delayed(headStart);
      if (done.isCompleted) return;
      try {
        if (await probe(uri, cancel) && !done.isCompleted) done.complete(uri);
      } catch (_) {
        // Timeout, TLS, HTTP or socket failure: the other candidates may work.
      } finally {
        if (--remaining == 0 && !done.isCompleted) done.complete(null);
      }
    }

    for (final uri in usable) {
      unawaited(run(uri));
    }
    final winner = await done.future;
    deadline.cancel();
    cancel.cancel('route selected');
    _active.remove(cancel);
    if (winner != null && generation == _generation) {
      _preferredHost = winner.host;
      _preferredUntil = now().add(const Duration(minutes: 5));
      return winner.toString();
    }
    // A short probe is not proof that playback is impossible. Keep an original
    // service URL as the final fallback rather than inventing another host.
    return candidates
            .where(
              (u) =>
                  !overseasMediaHosts.contains(u.host) &&
                  !_failed.containsKey(u.host),
            )
            .firstOrNull
            ?.toString() ??
        usable.last.toString();
  }
}

/// Caller owns the client. A cancelled losing probe closes its response stream.
/// Range is advisory: servers may ignore it, so stop consuming at the sample.
Future<bool> probeMediaRange(Dio client, Uri uri, CancelToken cancel) async {
  const sampleBytes = 16 * 1024;
  final response = await client.getUri<ResponseBody>(
    uri,
    cancelToken: cancel,
    options: Options(
      responseType: ResponseType.stream,
      followRedirects: false,
      validateStatus: (_) => true,
      headers: {'Range': 'bytes=0-${sampleBytes - 1}'},
    ),
  );
  final body = response.data;
  if (body == null) return false;
  final type = response.headers.value('content-type')?.toLowerCase() ?? '';
  final valid =
      (response.statusCode == 200 || response.statusCode == 206) &&
      (type.startsWith('video/') ||
          type.startsWith('audio/') ||
          type.startsWith('application/octet-stream') ||
          type.startsWith('binary/'));
  if (!valid) {
    await body.stream.listen((_) {}).cancel();
    return false;
  }
  var bytes = 0;
  await for (final chunk in body.stream) {
    if (cancel.isCancelled) return false;
    bytes += chunk.length;
    if (bytes >= sampleBytes) return true;
  }
  return bytes > 0;
}
