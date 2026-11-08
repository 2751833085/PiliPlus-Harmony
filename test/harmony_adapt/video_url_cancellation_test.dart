import 'dart:async';

import 'package:PiliPlus/http/api.dart';
import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/models/common/video/source_type.dart';
import 'package:PiliPlus/models/common/video/video_type.dart';
import 'package:PiliPlus/models/video/play/url.dart';
import 'package:PiliPlus/pages/video/controller.dart';
import 'package:PiliPlus/utils/accounts/account_manager/account_mgr.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'helpers/memory_box.dart';

const _deadline = Duration(seconds: 2);
const _bvid = 'BV1xx411c7mD';

class _Video extends VideoDetailController {
  _Video() {
    args = {};
    videoType = VideoType.pgc;
    sourceType = SourceType.normal;
    isFileSource = false;
    bvid = _bvid;
    cid = 1.obs;
    plPlayerController.cacheVideoQa = 64;
    autoPlay = true;
  }

  final opened = <int>[];

  @override
  Future<void> playerInit({
    bool? autoplay,
    bool autoFullScreenFlag = false,
    bool resolveRoutes = true,
  }) async => opened.add(cid.value);
}

typedef _Request = (RequestOptions, RequestInterceptorHandler);

void _respond(_Request request, Map<String, Object> data) {
  final (options, handler) = request;
  if (handler.isCompleted) return;
  handler.resolve(
    Response(requestOptions: options, statusCode: 200, data: data),
  );
}

Map<String, Object> _playUrl(Map<String, Object> videoInfo) => {
  'code': 0,
  'result': {'video_info': videoInfo},
};

Map<String, Object> _completeVideo(int cid) => _playUrl({
  'quality': 64,
  'durl': [
    {'url': 'https://fixture.invalid/$cid.mp4', 'length': 1200},
  ],
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GStorage.setting = MemoryBox();
    GStorage.video = MemoryBox();
    GStorage.localCache = MemoryBox();
    Request();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger
      ..setMockMessageHandler(
        'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
        (_) async => const StandardMessageCodec().encodeMessage([null]),
      )
      ..setMockMethodCallHandler(SystemChannels.platform, (_) async => null)
      ..setMockMethodCallHandler(
        const MethodChannel('native_device_orientation_events'),
        (_) async => null,
      );
  });

  setUp(() async {
    await GStorage.localCache.delete(LocalCacheKey.timeStamp);
    await GStorage.localCache.delete(LocalCacheKey.mixinKey);
    await GStorage.setting.put(SettingBoxKey.enableSponsorBlock, false);
  });

  Future<void> cacheSigningKey() async {
    await GStorage.localCache.put(
      LocalCacheKey.timeStamp,
      DateTime.now().millisecondsSinceEpoch,
    );
    await GStorage.localCache.put(LocalCacheKey.mixinKey, 'fixture-key');
  }

  void intercept(
    void Function(RequestOptions, RequestInterceptorHandler) onRequest,
  ) {
    final interceptor = InterceptorsWrapper(onRequest: onRequest);
    Request.dio.interceptors.insert(0, interceptor);
    addTearDown(() => Request.dio.interceptors.remove(interceptor));
  }

  testWidgets(
    'episode reset cancels a stalled play URL silently and starts its successor',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: FlutterSmartDialog.init(),
          home: const Scaffold(body: Text('番剧详情')),
        ),
      );
      final accountInterceptor = AccountManager();
      Request.dio.interceptors.add(accountInterceptor);
      addTearDown(() => Request.dio.interceptors.remove(accountInterceptor));
      await tester.runAsync(() async {
        await cacheSigningKey();
        final video = _Video();
        addTearDown(video.plPlayerController.dispose);
        final held = Completer<_Request>();
        intercept((options, handler) {
          expect(options.path, VideoType.pgc.api);
          final cid = options.queryParameters['cid'] as int;
          if (cid == 1) {
            held.complete((options, handler));
          } else {
            _respond((options, handler), _completeVideo(cid));
          }
        });
        final old = video.queryVideoUrl();
        final pending = await held.future.timeout(_deadline);
        addTearDown(() => _respond(pending, _completeVideo(1)));

        video.onReset();
        video.cid.value = 2;
        await video.queryVideoUrl().timeout(_deadline);
        expect(pending.$1.cancelToken?.isCancelled, isTrue);
        expect(video.opened, [2]);
        expect(video.videoUrl, 'https://fixture.invalid/2.mp4');

        _respond(pending, _completeVideo(1));
        await old.timeout(_deadline);
        expect(video.opened, [2]);
        expect(video.videoUrl, 'https://fixture.invalid/2.mp4');
      });
      await tester.pump();
      expect(SmartDialog.config.toast.isExist, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'a superseded quality supplement never publishes a partial model',
    () async {
      await cacheSigningKey();
      final previous = PlayUrlModel(quality: 16);
      final video = _Video()..data = previous;
      addTearDown(video.plPlayerController.dispose);
      final held = Completer<_Request>();
      intercept((options, handler) {
        expect(options.path, VideoType.pgc.api);
        final cid = options.queryParameters['cid'] as int;
        if (cid == 2) {
          _respond((options, handler), _completeVideo(cid));
        } else if (options.queryParameters['qn'] == 64) {
          held.complete((options, handler));
        } else {
          _respond(
            (options, handler),
            _playUrl({
              'quality': 80,
              'accept_quality': [80, 64],
              'support_formats': [
                {'quality': 80},
                {'quality': 64},
              ],
              'dash': {
                'video': [
                  {'id': 80, 'baseUrl': 'https://fixture.invalid/old.m4s'},
                ],
              },
            }),
          );
        }
      });
      final old = video.queryVideoUrl();
      final pending = await held.future.timeout(_deadline);
      addTearDown(() => _respond(pending, _completeVideo(1)));
      expect(video.data, same(previous));
      expect(video.opened, isEmpty);

      video.cid.value = 2;
      await video.queryVideoUrl().timeout(_deadline);
      expect(pending.$1.cancelToken?.isCancelled, isTrue);
      _respond(pending, _completeVideo(1));
      await old.timeout(_deadline);
      expect(video.data.quality, 64);
      expect(video.opened, [2]);
    },
  );

  test(
    'route exit releases a cold WBI waiter while the next request reuses its key',
    () async {
      final video = _Video();
      addTearDown(video.plPlayerController.dispose);
      final held = Completer<_Request>();
      final videoCids = <int>[];
      var keyRequests = 0;
      intercept((options, handler) {
        if (options.path == Api.userInfo) {
          keyRequests++;
          held.complete((options, handler));
        } else {
          expect(options.path, VideoType.pgc.api);
          final cid = options.queryParameters['cid'] as int;
          expect(options.queryParameters['w_rid'], isA<String>());
          videoCids.add(cid);
          _respond((options, handler), _completeVideo(cid));
        }
      });
      final old = video.queryVideoUrl();
      final pending = await held.future.timeout(_deadline);
      final signingKey = {
        'code': 0,
        'data': {
          'wbi_img': {
            'img_url': 'https://fixture.invalid/${'a' * 32}.png',
            'sub_url': 'https://fixture.invalid/${'b' * 32}.png',
          },
        },
      };
      addTearDown(() => _respond(pending, signingKey));

      video.suspendPlayback(cancelVideoQuery: true);
      await old.timeout(_deadline);
      expect(video.isQuerying, isFalse);
      expect(videoCids, isEmpty);

      video.activatePlayback();
      video.cid.value = 2;
      final next = video.queryVideoUrl();
      await Future<void>.delayed(Duration.zero);
      expect(video.isQuerying, isTrue);
      expect(videoCids, isEmpty);
      _respond(pending, signingKey);
      await next.timeout(_deadline);
      expect(keyRequests, 1);
      expect(videoCids, [2]);
      expect(video.opened, [2]);
    },
  );
}
