import 'package:PiliPlus/models_new/video/video_detail/dimension.dart';
import 'package:PiliPlus/models/model_owner.dart';
import 'package:PiliPlus/models/model_video.dart';

abstract class BaseRcmdVideoItemModel extends BaseVideoItemModel {
  Dimension? dimension;
  bool get isPortraitVideo =>
      (dimension?.width ?? 0) > 0 &&
      (dimension?.height ?? 0) > 0 &&
      dimension!.height! > dimension!.width!;

  void readDimension(Map<String, dynamic> json) {
    final data = json['dimension'] ?? json['player_args']?['dimension'];
    if (data is Map<String, dynamic>) {
      dimension = Dimension.fromJson(data);
      return;
    }
    final parameters = Uri.tryParse(
      json['uri'] as String? ?? '',
    )?.queryParameters;
    final width = int.tryParse(parameters?['player_width'] ?? '');
    final height = int.tryParse(parameters?['player_height'] ?? '');
    if (width != null && height != null) {
      dimension = Dimension.fromJson({
        'width': width,
        'height': height,
        'rotate': int.tryParse(parameters?['player_rotate'] ?? '') ?? 0,
      });
    }
  }

  String? goto;
  String? uri;
  String? rcmdReason;

  // app推荐专属
  int? param;
  String? pgcBadge;
}

class RcmdVideoItemModel extends BaseRcmdVideoItemModel {
  RcmdVideoItemModel.fromJson(Map<String, dynamic> json) {
    readDimension(json);
    aid = json["id"];
    bvid = json["bvid"];
    cid = json["cid"];
    goto = json["goto"];
    uri = json["uri"];
    cover = json["pic"];
    title = json["title"];
    duration = json["duration"];
    pubdate = json["pubdate"];
    owner = Owner.fromJson(json["owner"]);
    stat = Stat.fromJson(json["stat"]);
    isFollowed = json["is_followed"] == 1;
    // rcmdReason = json["rcmd_reason"] != null
    //     ? RcmdReason.fromJson(json["rcmd_reason"])
    //     : RcmdReason(content: '');
    rcmdReason = json["rcmd_reason"]?['content'];
  }

  // @override
  // String? get desc => null;
}

// @HiveType(typeId: 2)
// class RcmdReason {
//   RcmdReason({
//     this.reasonType,
//     this.content,
//   });
// //   int? reasonType;
// //   String? content;
//
//   RcmdReason.fromJson(Map<String, dynamic> json) {
//     reasonType = json["reason_type"];
//     content = json["content"] ?? '';
//   }
// }
