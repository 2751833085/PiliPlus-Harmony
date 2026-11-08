import 'dart:async';

import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart'
    show MainListReply, Mode, ReplyInfo;
import 'package:PiliPlus/http/api.dart';
import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/video/source_type.dart';
import 'package:PiliPlus/models/common/video/video_type.dart';
import 'package:PiliPlus/models_new/pgc/pgc_info_model/episode.dart' as pgc;
import 'package:PiliPlus/models_new/video/video_detail/episode.dart';
import 'package:PiliPlus/pages/video/controller.dart';
import 'package:PiliPlus/pages/video/introduction/pgc/controller.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/controller.dart';
import 'package:PiliPlus/pages/video/reply/controller.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:dio/dio.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'helpers/memory_box.dart';

const _tag = 'episode-fixture';
const _bvid = 'BV1xx411c7mD';

class _Video extends VideoDetailController {
  _Video(VideoType type, {this.showReply = false}) {
    videoType = type;
    sourceType = SourceType.normal;
    isPlayAll = false;
    bvid = _bvid;
    aid = 1;
    cid = 1.obs;
    cover = ''.obs;
    epId = 1;
  }

  @override
  final bool showReply;
  final opened = <int>[];

  @override
  Future<void> queryVideoUrl({
    bool fromReset = false,
    bool autoFullScreenFlag = false,
  }) async => opened.add(cid.value);

  @override
  void makeHeartBeat() {}

  @override
  void onReset({bool isStein = false}) {}

  @override
  void updateMediaListHistory(int aid) {}
}

class _Pgc extends PgcIntroController {
  _Pgc(this._video) {
    heroTag = _tag;
    bvid = _bvid;
    cid = 1.obs;
    hasLater = false.obs;
    isPgc = false;
    epId = 1;
  }

  final VideoDetailController _video;

  @override
  VideoDetailController get videoDetailCtr => _video;

  @override
  void queryVideoIntro([pgc.EpisodeItem? episode]) {}
}

class _Ugc extends UgcIntroController {
  _Ugc(this._video) {
    heroTag = _tag;
    bvid = _bvid;
    cid = 1.obs;
    hasLater = false.obs;
  }

  final VideoDetailController _video;

  @override
  VideoDetailController get videoDetailCtr => _video;
}

class _Replies extends VideoReplyController {
  _Replies(this._video)
    : super(aid: 1, videoType: VideoType.pugv, heroTag: _tag);

  final VideoDetailController _video;

  @override
  VideoDetailController get videoCtr => _video;

  final calls = <(int, Completer<LoadingState<MainListReply>>)>[];

  @override
  Future<LoadingState<MainListReply>> loadReplyPage({
    required int oid,
    required int type,
    required Mode mode,
    required Int64? cursorNext,
    required String? offset,
    CancelToken? cancelToken,
    bool silent = false,
  }) {
    final reply = Completer<LoadingState<MainListReply>>();
    calls.add((oid, reply));
    return reply.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    GStorage.setting = MemoryBox();
    GStorage.video = MemoryBox();
    GStorage.localCache = MemoryBox();
    Request();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMessageHandler(
        'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
        (_) async => const StandardMessageCodec().encodeMessage([null]),
      )
      ..setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });

  for (final type in [VideoType.ugc, VideoType.pgc]) {
    for (final exit in [false, true]) {
      test(
        '$type ignores delayed episode lookup after ${exit ? 'route exit' : 'newer selection'}',
        () async {
          final video = _Video(type);
          addTearDown(video.plPlayerController.dispose);
          final Future<bool> Function(BaseEpisodeItem) select =
              type == VideoType.pgc
              ? _Pgc(video).onChangeEpisode
              : _Ugc(video).onChangeEpisode;
          final requested =
              Completer<(RequestOptions, RequestInterceptorHandler)>();
          final interceptor = InterceptorsWrapper(
            onRequest: (options, handler) {
              expect(options.path, Api.ab2c);
              requested.complete((options, handler));
            },
          );
          Request.dio.interceptors.insert(0, interceptor);
          addTearDown(() => Request.dio.interceptors.remove(interceptor));

          final slow = select(pgc.EpisodeItem(id: 11, aid: 11, bvid: _bvid));
          final (options, handler) = await requested.future;
          if (exit) {
            // The route notifies the controller at pop, before disposal runs.
            video.suspendPlayback(cancelVideoQuery: true);
          } else {
            expect(
              await select(
                pgc.EpisodeItem(id: 22, aid: 22, bvid: _bvid, cid: 22),
              ),
              isTrue,
            );
          }
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'code': 0,
                'data': [
                  {'cid': 11},
                ],
              },
            ),
          );

          expect(await slow, isFalse);
          expect(video.opened, exit ? isEmpty : [22]);
          expect(video.cid.value, exit ? 1 : 22);
        },
      );
    }
  }

  test(
    'course switch invalidates pending replies even when aid is unchanged',
    () async {
      final video = _Video(VideoType.pugv, showReply: true);
      addTearDown(video.plPlayerController.dispose);
      final replies =
          Get.put<VideoReplyController>(_Replies(video), tag: _tag) as _Replies;
      addTearDown(() => Get.delete<VideoReplyController>(tag: _tag));
      final old = replies.queryData();
      expect(replies.calls.map((call) => call.$1), [1]);

      final selection = _Pgc(video);
      expect(
        await selection.onChangeEpisode(
          pgc.EpisodeItem(id: 2, aid: 1, bvid: _bvid, cid: 2),
        ),
        isTrue,
      );
      expect(replies.calls.map((call) => call.$1), [1, 2]);
      final applied = Completer<void>();
      final worker = ever(replies.loadingState, (state) {
        if (state.dataOrNull?.singleOrNull?.id == Int64(200) &&
            !applied.isCompleted) {
          applied.complete();
        }
      });
      addTearDown(worker.dispose);
      replies.calls.last.$2.complete(
        Success(MainListReply(replies: [ReplyInfo(id: Int64(200))])),
      );
      await applied.future;
      replies.calls.first.$2.complete(
        Success(MainListReply(replies: [ReplyInfo(id: Int64(100))])),
      );
      await old;
      expect(replies.loadingState.value.dataOrNull?.single.id, Int64(200));
    },
  );
}
