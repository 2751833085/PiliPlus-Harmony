import 'package:PiliPlus/models_new/video/video_tag/data.dart';

/// Derive a contextual search from the current video's existing metadata.
/// This does not claim to use the official client's private recommendation API.
String? shortVideoSearchTerm({List<VideoTagItem>? tags, String? title}) {
  final cleanTitle = title?.trim() ?? '';
  final candidates = <String>{
    for (final tag in tags ?? const <VideoTagItem>[])
      if (tag.tagType != 'bgm' && (tag.tagName?.trim().isNotEmpty ?? false))
        tag.tagName!.trim(),
  }.toList();
  final matching =
      candidates
          .where((tag) => cleanTitle.toLowerCase().contains(tag.toLowerCase()))
          .toList()
        ..sort((a, b) => b.length.compareTo(a.length));
  if (matching.isNotEmpty) return matching.first;
  if (candidates.isNotEmpty) return candidates.first;
  return cleanTitle.isEmpty ? null : cleanTitle;
}
