import 'package:dio/dio.dart' show CancelToken;
import 'package:fixnum/fixnum.dart' show Int64;
import 'package:PiliPlus/pages/video/shorts/preloader.dart';
import 'package:PiliPlus/pages/video/shorts/session.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart'
    show MainListReply, ReplyInfo, Mode;
import 'package:PiliPlus/grpc/reply.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/video/video_type.dart';
import 'package:PiliPlus/pages/common/reply_controller.dart';
import 'package:PiliPlus/pages/video/controller.dart';
import 'package:PiliPlus/pages/video/reply/vote/reply_vote_mixin.dart';
import 'package:PiliPlus/utils/id_utils.dart';
import 'package:get/get.dart';

class VideoReplyController extends ReplyController<MainListReply>
    with ReplyVoteMixin {
  VideoReplyController({
    required this.aid,
    required this.videoType,
    required this.heroTag,
  });
  int aid;
  bool _allowPreloaded = true;
  Object get _preloadContext => (
    Accounts.main,
    Accounts.video,
    mode.value,
    Pref.banWordForReply,
    Pref.antiGoodsReply,
  );
  late final _preloaded = NextVideoPreloader<MainListReply>(
    capacity: 5,
    load: (_, nextAid, cancel) async => (await loadReplyPage(
      oid: nextAid,
      type: videoType.replyType,
      mode: mode,
      cursorNext: null,
      offset: null,
      cancelToken: cancel,
      silent: true,
    )).dataOrNull,
    warm: (_, _) async {},
  );

  Future<void> preloadWindow(List<ShortVideoEntry> entries) async {
    if (isClosed || isPugv || !Pref.shortPreload) return;
    final context = _preloadContext;
    final ids = {
      for (final entry in entries.take(4))
        entry.aid ?? IdUtils.bv2av(entry.bvid),
    }..remove(aid);
    _preloaded.retain({
      aid.toString(),
      ...ids.map((id) => id.toString()),
    }, context);
    await Future.wait([
      for (final id in ids) _preloaded.prepare(id.toString(), id, context),
    ]);
  }

  void cancelPreload() => _preloaded.cancel();

  @override
  void onClose() {
    _preloaded.dispose();
    super.onClose();
  }

  void changeVideo(int nextAid) {
    if (aid == nextAid) return;
    aid = nextAid;
    _allowPreloaded = true;
    invalidateRequests();
    count.value = -1;
    onReload();
  }

  final VideoType videoType;
  late final isPugv = videoType == VideoType.pugv;

  final String heroTag;
  late final videoCtr = Get.find<VideoDetailController>(tag: heroTag);

  @override
  dynamic get sourceId => IdUtils.av2bv(aid);

  @override
  List<ReplyInfo>? getDataList(MainListReply response) {
    return response.replies;
  }

  Future<LoadingState<MainListReply>> loadReplyPage({
    required int oid,
    required int type,
    required Mode mode,
    required Int64? cursorNext,
    required String? offset,
    CancelToken? cancelToken,
    bool silent = false,
  }) => ReplyGrpc.mainList(
    oid: oid,
    type: type,
    mode: mode,
    cursorNext: cursorNext,
    offset: offset,
    cancelToken: cancelToken,
    silent: silent,
  );

  @override
  Future<LoadingState<MainListReply>> customGetData() async {
    final requestedAid = aid;
    final requestedMode = mode;
    final context = _preloadContext;
    final useCache = _allowPreloaded && cursorNext == null && !isPugv;
    _allowPreloaded = false;
    if (useCache) {
      final cached = await _preloaded.take(
        requestedAid.toString(),
        requestedAid,
        context,
      );
      if (isClosed || requestedAid != aid || context != _preloadContext) {
        return const Error('评论请求已切换');
      }
      if (cached != null) {
        // ReplyController inserts pinned replies and UI edits likes locally.
        // Never let these mutations contaminate a reusable cached response.
        return Success(MainListReply.fromBuffer(cached.writeToBuffer()));
      }
    }
    return loadReplyPage(
      oid: isPugv ? videoCtr.epId! : requestedAid,
      type: videoType.replyType,
      mode: requestedMode,
      cursorNext: cursorNext,
      offset: paginationReply?.nextOffset,
    );
  }
}
