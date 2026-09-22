import 'package:PiliPlus/http/search.dart';
import 'package:PiliPlus/models_new/history/list.dart';
import 'package:PiliPlus/models_new/video/video_detail/dimension.dart';
import 'package:PiliPlus/utils/id_utils.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

/// Shared by the complete history list and the optional Mine preview.
Future<void> openHistoryItem(HistoryItemModel item) async {
  final h = item.history;
  final business = h.business;
  if (business?.contains('article') == true) {
    final id = business == 'article-list' ? h.cid : h.oid;
    if (id == null) return _unavailable();
    PageUtils.toDupNamed(
      '/articlePage',
      parameters: {'id': '$id', 'type': 'read'},
    );
  } else if (business == 'live') {
    if (item.liveStatus == 1 && h.oid != null) {
      PageUtils.toLiveRoom(h.oid);
    } else {
      SmartDialog.showToast('直播未开播');
    }
  } else if (business == 'pgc') {
    if (h.epid == null) return _unavailable();
    await PageUtils.viewPgc(epId: h.epid, progress: item.playbackProgress);
  } else if (business == 'cheese') {
    if (item.uri?.isNotEmpty != true) return _unavailable();
    PageUtils.viewPgcFromUri(
      item.uri!,
      isPgc: false,
      aid: h.oid,
      progress: item.playbackProgress,
    );
  } else {
    if ((h.bvid == null || h.bvid!.isEmpty) && (h.oid == null || h.oid! <= 0)) {
      return _unavailable();
    }
    final bvid = h.bvid?.isNotEmpty == true ? h.bvid! : IdUtils.av2bv(h.oid!);
    var cid = h.cid;
    Dimension? dimension;
    if (cid == null) {
      final result = await SearchHttp.ab2cWithDimension(
        aid: h.oid,
        bvid: bvid,
        part: h.page,
      );
      cid = result?.cid;
      dimension = result?.dimension;
    }
    if (cid == null) return _unavailable();
    await PageUtils.toVideoPage(
      aid: h.oid,
      bvid: bvid,
      cid: cid,
      cover: item.cover,
      title: item.title,
      dimension: dimension,
      progress: item.playbackProgress,
    );
  }
}

void _unavailable() => SmartDialog.showToast('这条观看记录暂时无法打开');
