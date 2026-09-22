import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:dio/dio.dart';

class _Prefix {
  _Prefix(
    this.url,
    this.bytes,
    this.total,
    this.type,
    this.validator,
    this.token,
  );
  final String url, type, token;
  Uint8List bytes;
  final int total;
  final String? validator;
}

class _PendingPrefix {
  _PendingPrefix(this.token, this.cancel);
  final String token;
  final CancelToken cancel;
  final ready = Completer<_Prefix?>();
}

/// Loopback-only, bounded current + three-neighbour media cache. A decoder can
/// join an in-flight warmup as soon as its first validated bytes arrive.
class ShortMediaCache {
  ShortMediaCache(this.client);
  final Dio client;
  final Map<String, _Prefix> _entries = {};
  final Map<String, _PendingPrefix> _pending = {};
  // Keep issued addresses valid until their source leaves the moving window.
  // A failed warmup may already have handed its loopback URL to the decoder.
  final Map<String, String> _tokens = {};
  // Includes the outgoing decoder during a source handoff.
  static const maxStreams = 10;
  static const maxPrefixBytes = 1024 * 1024;
  final Set<CancelToken> _transfers = {};
  HttpServer? _server;
  Future<HttpServer>? _starting;
  bool _closed = false;
  final String _secret = List.generate(
    20,
    (_) => math.Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  int _id = 0;
  int get bytesHeld => _entries.values.fold(0, (n, p) => n + p.bytes.length);
  int get entriesHeld => _entries.length;

  Future<void> warm(String url, int limit, CancelToken cancel) async {
    if (_closed ||
        cancel.isCancelled ||
        _entries.containsKey(url) ||
        _pending.containsKey(url))
      return;
    if ((!_tokens.containsKey(url) && _tokens.length >= maxStreams) ||
        limit <= 0)
      return;
    limit = math.min(limit, maxPrefixBytes);
    final uri = Uri.tryParse(url);
    if (uri == null || !['http', 'https'].contains(uri.scheme)) return;
    final pending = _PendingPrefix(
      _tokens.putIfAbsent(url, () => '$_secret/${_id++}'),
      cancel,
    );
    _pending[url] = pending;
    try {
      await (_starting ??= HttpServer.bind(InternetAddress.loopbackIPv4, 0)
          .then((server) {
            if (_closed) {
              server.close(force: true);
              throw StateError('cache disposed');
            }
            _server = server;
            server.listen(_serve, onError: (Object _) {});
            return server;
          }));
      final result = await client.get<ResponseBody>(
        url,
        cancelToken: cancel,
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Range': 'bytes=0-${limit - 1}'},
          validateStatus: (_) => true,
        ),
      );
      final body = result.data;
      if (body == null) return;
      final type =
          result.headers.value('content-type') ?? 'application/octet-stream';
      final range = RegExp(
        r'^bytes 0-(\d+)/(\d+)$',
      ).firstMatch(result.headers.value('content-range') ?? '');
      final total = range == null
          ? int.tryParse(result.headers.value('content-length') ?? '')
          : int.parse(range[2]!);
      final validType =
          type.startsWith('video/') ||
          type.startsWith('audio/') ||
          type.startsWith('application/octet-stream');
      final validRange =
          result.statusCode == 206 &&
          range != null &&
          int.parse(range[1]!) + 1 == math.min(total!, limit);
      final complete =
          result.statusCode == 200 && total != null && total <= limit;
      if (!validType ||
          total == null ||
          total <= 0 ||
          !(validRange || complete)) {
        await body.stream.listen((_) {}).cancel();
        return;
      }
      final expected = math.min(total, limit);
      final bytes = BytesBuilder(copy: false);
      _Prefix? prefix;
      await for (final chunk in body.stream) {
        if (_closed || cancel.isCancelled || !identical(_pending[url], pending))
          return;
        final remaining = expected - bytes.length;
        bytes.add(
          chunk.length > remaining
              ? Uint8List.sublistView(chunk, 0, remaining)
              : chunk,
        );
        // Publish a trustworthy initial prefix early. The decoder may use it
        // while the rest downloads; range stitching fetches only missing bytes.
        if (prefix == null && bytes.length >= math.min(64 * 1024, expected)) {
          prefix = _Prefix(
            url,
            bytes.toBytes(),
            total,
            type,
            result.headers.value('etag') ??
                result.headers.value('last-modified'),
            pending.token,
          );
          _entries[url] = prefix;
          pending.ready.complete(prefix);
        }
        if (bytes.length == expected) break;
      }
      if (!_closed &&
          !cancel.isCancelled &&
          identical(_pending[url], pending) &&
          prefix != null) {
        prefix.bytes = bytes.takeBytes();
      }
    } catch (_) {
      // Failure falls back to the foreground URL; already validated prefixes
      // remain usable even if their speculative tail was cancelled.
    } finally {
      if (!pending.ready.isCompleted) pending.ready.complete(null);
      if (identical(_pending[url], pending)) _pending.remove(url);
    }
  }

  Future<String> playbackSourceFor(String url) async {
    try {
      await _starting;
    } catch (_) {}
    return sourceFor(url);
  }

  String sourceFor(String url) {
    final token = _entries[url]?.token ?? _pending[url]?.token;
    return token == null || _server == null || _closed
        ? url
        : 'http://127.0.0.1:${_server!.port}/$token';
  }

  bool contains(String? url) => url != null && _entries.containsKey(url);
  void retain(Set<String> urls) {
    _tokens.removeWhere((url, _) => !urls.contains(url));
    _entries.removeWhere((url, _) => !urls.contains(url));
    for (final url in _pending.keys.toList()) {
      if (!urls.contains(url)) {
        final pending = _pending.remove(url)!;
        pending.cancel.cancel('outside media window');
        if (!pending.ready.isCompleted) pending.ready.complete(null);
      }
    }
  }

  void evict(String? url) {
    if (url == null) return;
    _tokens.remove(url);
    _entries.remove(url);
    final pending = _pending.remove(url);
    if (pending != null) {
      pending.cancel.cancel('evicted media');
      if (!pending.ready.isCompleted) pending.ready.complete(null);
    }
  }

  Future<void> _serve(HttpRequest request) async {
    final response = request.response;
    CancelToken? cancel;
    try {
      if (request.method != 'GET' && request.method != 'HEAD') {
        response.statusCode = 405;
        await response.close();
        return;
      }
      final pending = _pending.values
          .where((p) => '/${p.token}' == request.uri.path)
          .firstOrNull;
      final prefix =
          _entries.values
              .where((p) => '/${p.token}' == request.uri.path)
              .firstOrNull ??
          (pending == null ? null : await pending.ready.future);

      final origin = _tokens.entries
          .where((entry) => '/${entry.value}' == request.uri.path)
          .firstOrNull
          ?.key;
      if (_closed || origin == null) {
        response.statusCode = 404;
        await response.close();
        return;
      }
      if (prefix == null) {
        // Speculation is optional: preserve the decoder's request method and
        // Range header by redirecting to the original source, without waiting
        // for the player's slower error/reinitialization fallback.
        response.statusCode = HttpStatus.temporaryRedirect;
        response.headers.set(HttpHeaders.locationHeader, origin);
        response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
        await response.close();
        return;
      }
      final requested = request.headers.value('range');
      var start = 0, end = prefix.total - 1;
      if (requested != null) {
        final match = RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(requested);
        if (match == null || (match[1]!.isEmpty && match[2]!.isEmpty)) {
          response.statusCode = 416;
          await response.close();
          return;
        }
        if (match[1]!.isEmpty) {
          start = math.max(0, prefix.total - int.parse(match[2]!));
        } else {
          start = int.parse(match[1]!);
          if (match[2]!.isNotEmpty) end = math.min(end, int.parse(match[2]!));
        }
      }
      if (start > end || start >= prefix.total) {
        response.statusCode = 416;
        response.headers.set('Content-Range', 'bytes */${prefix.total}');
        await response.close();
        return;
      }
      response.statusCode = requested == null ? 200 : 206;
      response.headers.set('Content-Type', prefix.type);
      response.headers.set('Accept-Ranges', 'bytes');
      response.headers.set('Cache-Control', 'no-store');
      if (requested != null)
        response.headers.set(
          'Content-Range',
          'bytes $start-$end/${prefix.total}',
        );
      response.contentLength = end - start + 1;
      if (request.method == 'HEAD') {
        await response.close();
        return;
      }
      if (start < prefix.bytes.length) {
        final cachedEnd = math.min(prefix.bytes.length, end + 1);
        response.add(Uint8List.sublistView(prefix.bytes, start, cachedEnd));
        start = cachedEnd;
        // Deliver cached startup bytes before awaiting a remote tail RTT.
        await response.flush();
      }
      if (start <= end) {
        cancel = CancelToken();
        _transfers.add(cancel);
        // Decoder disconnects and seek cancellations abort their remote request.
        unawaited(
          response.done.then<void>(
            (_) => cancel?.cancel(),
            onError: (Object _) => cancel?.cancel(),
          ),
        );
        final remote = await client.get<ResponseBody>(
          prefix.url,
          cancelToken: cancel,
          options: Options(
            responseType: ResponseType.stream,
            validateStatus: (_) => true,
            headers: {
              'Range': 'bytes=$start-$end',
              if (prefix.validator != null) 'If-Range': prefix.validator,
            },
          ),
        );
        final expectedRange = 'bytes $start-$end/${prefix.total}';
        if (remote.statusCode != 206 ||
            remote.headers.value('content-range') != expectedRange ||
            remote.data == null) {
          if (remote.data != null)
            await remote.data!.stream.listen((_) {}).cancel();
          throw StateError('media range changed');
        }
        await response.addStream(remote.data!.stream);
      }
      await response.close();
    } catch (_) {
      try {
        await response.close();
      } catch (_) {}
    } finally {
      if (cancel != null) {
        cancel.cancel();
        _transfers.remove(cancel);
      }
    }
  }

  Future<void> dispose() async {
    _closed = true;
    retain({});
    for (final token in _transfers.toList()) {
      token.cancel('cache disposed');
    }
    await _server?.close(force: true);
  }
}
