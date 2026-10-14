import 'package:PiliPlus/models_new/video/video_detail/stat_detail.dart';

class VideoStat extends StatDetail {
  int? dislike;
  String dislikeLabel({required bool showCount}) => !showCount
      ? '点踩'
      : dislike == null
      ? '未公开'
      : dislike.toString();
  VideoStat.fromJson(Map<String, dynamic> json) {
    final rawDislike = json['dislike'];
    // Public view responses use 0 as a placeholder, not a disclosed total.
    dislike = rawDislike is int && rawDislike > 0 ? rawDislike : null;
    view = json['view'] as int?;
    danmaku = json['danmaku'] as int?;
    reply = json['reply'] as int?;
    favorite = json['favorite'] as int? ?? 0;
    coin = json['coin'] as num? ?? 0;
    share = json['share'] as int?;
    like = json['like'] as int? ?? 0;
  }
}
