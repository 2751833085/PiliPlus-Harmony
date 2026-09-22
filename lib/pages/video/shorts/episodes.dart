import 'package:PiliPlus/models_new/video/video_detail/data.dart';
import 'package:PiliPlus/models_new/video/video_detail/episode.dart';
import 'package:PiliPlus/models_new/video/video_detail/page.dart';
import 'package:PiliPlus/models_new/video/video_detail/section.dart';

/// Snapshot the currently loaded video's choices; never use the unrelated
/// watch-later/favourites queue as the source for the short-video entry.
class ShortVideoEpisodes {
  ShortVideoEpisodes(VideoDetailData detail)
    : sections =
          detail.ugcSeason?.sections
              ?.where((section) => section.episodes?.isNotEmpty == true)
              .toList() ??
          const [],
      parts = (detail.pages?.length ?? 0) > 1 ? detail.pages! : const [];
  final List<SectionItem> sections;
  final List<Part> parts;
  bool get isEmpty => sections.isEmpty && parts.isEmpty;
  int sectionFor(int cid) {
    final index = sections.indexWhere(
      (s) => s.episodes!.any((episode) => episode.cid == cid),
    );
    return index < 0 ? 0 : index;
  }
}

BaseEpisodeItem prepareShortEpisode(
  BaseEpisodeItem episode, {
  required String bvid,
  required int aid,
  String? cover,
}) {
  if (episode is Part) {
    episode
      ..bvid = bvid
      ..aid = aid
      ..cover = episode.firstFrame ?? cover
      ..title = episode.part;
  }
  return episode;
}
