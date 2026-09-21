import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:PiliPlus/http/browser_ua.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'media_route_resolver.dart';

/// Per-page route state. It never shares account cookies or authentication
/// interceptors, and uses the platform's default TLS certificate validation.
class OverseasPlaybackRoutes {
  OverseasPlaybackRoutes() {
    _client = Dio(
      BaseOptions(
        connectTimeout: const Duration(milliseconds: 1500),
        receiveTimeout: const Duration(milliseconds: 1500),
        headers: {
          'User-Agent': BrowserUa.pc,
          'Referer': 'https://www.bilibili.com/',
        },
      ),
    );
    _client.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient()..autoUncompress = false;
        if (Pref.enableSystemProxy &&
            Pref.systemProxyHost.isNotEmpty &&
            int.tryParse(Pref.systemProxyPort) != null) {
          client.findProxy = (_) =>
              'PROXY ${Pref.systemProxyHost}:${Pref.systemProxyPort}';
        }
        return client;
      },
    );
    video = MediaRouteResolver(
      probe: (uri, token) => probeMediaRange(_client, uri, token),
    );
    audio = MediaRouteResolver(
      probe: (uri, token) => probeMediaRange(_client, uri, token),
    );
    var initialConnection = true;
    _network = Connectivity().onConnectivityChanged.listen((_) {
      if (initialConnection) {
        initialConnection = false;
      } else {
        reset();
      }
    }, onError: (Object _) {});
  }
  StreamSubscription<List<ConnectivityResult>>? _network;
  late final Dio _client;
  late final MediaRouteResolver video, audio;
  void reset() {
    video.reset();
    audio.reset();
  }

  void dispose() {
    _network?.cancel();
    reset();
    _client.close(force: true);
  }
}
