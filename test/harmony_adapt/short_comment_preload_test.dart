import 'dart:async';
import 'package:dio/dio.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/video/video_type.dart';
import 'package:PiliPlus/pages/video/reply/controller.dart';
import 'package:PiliPlus/pages/video/shorts/session.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'helpers/memory_box.dart';

class Replies extends VideoReplyController {
  Replies() : super(aid: 1, videoType: VideoType.ugc, heroTag: 'preload-test');
  final requests =
      <
        ({int oid, Mode mode, Int64? cursor, CancelToken? cancel, bool silent})
      >[];
  Completer<LoadingState<MainListReply>>? pending;
  MainListReply get response => MainListReply(
    cursor: CursorReply(next: Int64(7), isEnd: false),
    subjectControl: SubjectControl(count: Int64(20)),
    replies: [ReplyInfo(id: Int64(12))],
    upTop: ReplyInfo(id: Int64(10)),
  );
  @override
  Future<LoadingState<MainListReply>> loadReplyPage({
    required int oid,
    required int type,
    required Mode mode,
    required Int64? cursorNext,
    required String? offset,
    CancelToken? cancelToken,
    bool silent = false,
  }) async {
    requests.add((
      oid: oid,
      mode: mode,
      cursor: cursorNext,
      cancel: cancelToken,
      silent: silent,
    ));
    return pending?.future ?? Success(response);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    GStorage.setting = MemoryBox();
    GStorage.localCache = MemoryBox();
  });
  setUp(() async {
    await GStorage.setting.put(SettingBoxKey.shortPreload, true);
  });
  test(
    'next and previous comments reuse first page; refresh and pagination stay live',
    () async {
      final c = Replies()..onInit();
      await c.preloadWindow([
        const ShortVideoEntry(bvid: 'next', aid: 2),
        const ShortVideoEntry(bvid: 'prev', aid: 3),
      ]);
      expect(c.requests.length, 2);
      expect(c.requests.every((r) => r.silent && r.cursor == null), isTrue);
      c.changeVideo(2);
      await Future<void>.delayed(Duration.zero);
      expect(c.requests.length, 2);
      expect(c.count.value, 20);
      expect(c.cursorNext, Int64(7));
      expect(c.loadingState.value.data!.map((e) => e.id.toInt()), [10, 12]);
      await c.onLoadMore();
      expect(c.requests.last.cursor, Int64(7));
      await c.onRefresh();
      expect(c.requests.last.cursor, isNull);
      expect(c.requests.last.silent, isFalse);
      c.changeVideo(3);
      await Future<void>.delayed(Duration.zero);
      expect(c.requests.length, 4);
      // Cached protobuf stays untouched when pinned replies are inserted by UI.
      c.changeVideo(2);
      await Future<void>.delayed(Duration.zero);
      expect(c.loadingState.value.data!.map((e) => e.id.toInt()), [10, 12]);
      c.onClose();
    },
  );
  test(
    'obsolete comment requests cancel and cannot replace the selected video',
    () async {
      final c = Replies()..onInit();
      final pending = Completer<LoadingState<MainListReply>>();
      c.pending = pending;
      final warm = c.preloadWindow([
        const ShortVideoEntry(bvid: 'next', aid: 2),
      ]);
      c.changeVideo(2);
      c.pending = null;
      c.changeVideo(3);
      await c.preloadWindow([const ShortVideoEntry(bvid: 'new', aid: 4)]);
      expect(c.requests.first.cancel!.isCancelled, isTrue);
      // Resolve old work late: cancellation/revision must discard it.
      // NextVideoPreloader's foreground waiter is completed by retain().
      await Future<void>.delayed(Duration.zero);
      expect(c.aid, 3);
      expect(c.count.value, 20);
      c.onClose();
      pending.complete(Success(c.response));
      await warm;
    },
  );
  test('sort changes invalidate prefetched comments', () async {
    final c = Replies()..onInit();
    await c.preloadWindow([const ShortVideoEntry(bvid: 'next', aid: 2)]);
    c.mode = Mode.MAIN_LIST_TIME;
    c.changeVideo(2);
    await Future<void>.delayed(Duration.zero);
    expect(c.requests.length, 2);
    expect(c.requests.last.mode, Mode.MAIN_LIST_TIME);
    expect(c.requests.last.silent, isFalse);
    c.onClose();
  });
}
