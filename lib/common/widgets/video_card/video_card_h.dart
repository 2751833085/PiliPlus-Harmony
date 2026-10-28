import 'package:PiliPlus/common/widgets/video_card/video_card_h_layout.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/models/common/badge_type.dart';
import 'package:PiliPlus/models/common/stat_type.dart';
import 'package:PiliPlus/utils/num_utils.dart';
import 'package:PiliPlus/common/widgets/badge.dart';
import 'package:PiliPlus/common/widgets/image/image_save.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/progress_bar/video_progress_indicator.dart';
import 'package:PiliPlus/common/widgets/stat/stat.dart';
import 'package:PiliPlus/common/widgets/video_popup_menu.dart';
import 'package:PiliPlus/http/search.dart';
import 'package:PiliPlus/models/horizontal_video_model.dart';
import 'package:PiliPlus/models_new/video/video_detail/dimension.dart';
import 'package:PiliPlus/utils/date_utils.dart';
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:material_ui/material_ui.dart';

// 视频卡片 - 水平布局
class VideoCardH extends StatelessWidget {
  const VideoCardH({
    super.key,
    required this.videoItem,
    this.onTap,
    this.onViewLater,
    this.onRemove,
    this.adaptiveCover = false,
    this.compactSidebar = false,
  });
  final HorizontalVideoModel videoItem;
  final bool adaptiveCover;
  final bool compactSidebar;
  final VoidCallback? onTap;
  final ValueChanged<int>? onViewLater;
  final VoidCallback? onRemove;

  void onLongPress() => imageSaveDialog(
    bvid: videoItem.bvid,
    title: videoItem.title,
    cover: videoItem.cover,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = Material(
      type: .transparency,
      child: Stack(
        fit: compactSidebar ? StackFit.expand : StackFit.loose,
        clipBehavior: .none,
        children: [
          InkWell(
            onLongPress: onLongPress,
            onSecondaryTap: PlatformUtils.isMobile ? null : onLongPress,
            onTap: onTap ?? () => pushVideoH(videoItem),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Style.safeSpace,
                vertical: 5,
              ),
              child: LayoutBuilder(
                builder: (context, bounds) {
                  final coverWidth = VideoCardHLayout.coverWidth(
                    bounds.maxWidth,
                    bounds.maxHeight,
                    compactSidebar: compactSidebar,
                  );
                  final contentRow = Row(
                    crossAxisAlignment: .start,
                    children: [
                      SizedBox(
                        width: adaptiveCover || compactSidebar
                            ? coverWidth
                            : null,
                        child: AspectRatio(
                          aspectRatio: Style.aspectRatio,
                          child: _CoverBuilderH(
                            cover: videoItem.cover,
                            badge: videoItem.badge,
                            duration: videoItem.duration,
                            progress: videoItem.progress,
                            colorScheme: theme.colorScheme,
                          ),
                        ),
                      ),
                      SizedBox(width: compactSidebar ? 6 : 10),
                      compactSidebar ? _compactContent(theme) : content(theme),
                    ],
                  );
                  if (!compactSidebar) return contentRow;
                  return Stack(
                    children: [
                      contentRow,
                      Positioned(
                        left: coverWidth - 40,
                        bottom: 0,
                        width: 40,
                        height: 40,
                        child: VideoPopupMenu(
                          iconSize: 17,
                          iconOffset: const Offset(0, 7),
                          videoItem: videoItem,
                          onRemove: onRemove,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          if (!compactSidebar)
            Positioned(
              bottom: 3,
              right: 16,
              width: 29,
              height: 29,
              child: VideoPopupMenu(
                iconSize: 17,
                videoItem: videoItem,
                onRemove: onRemove,
              ),
            ),
        ],
      ),
    );
    return surface;
  }

  /// Keep metadata directly below the title. The menu sits below the cover,
  /// leaving this column's full width for readable play/danmaku counts.
  Widget _compactContent(ThemeData theme) {
    final pubdate = DateFormatUtils.dateFormat(videoItem.pubdate!);
    final metadata = [
      if (pubdate.isNotEmpty) pubdate,
      videoItem.owner.name,
    ].join('  ');
    final titleStyle = TextStyle(
      fontSize: theme.textTheme.bodyMedium!.fontSize,
      height: 1.28,
      letterSpacing: .1,
    );
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (videoItem.titleList?.isNotEmpty == true)
            Text.rich(
              TextSpan(
                children: [
                  for (final item in videoItem.titleList!)
                    TextSpan(
                      text: item.text,
                      style: item.isEm
                          ? TextStyle(color: theme.colorScheme.primary)
                          : null,
                    ),
                ],
              ),
              style: titleStyle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            )
          else
            Text(
              videoItem.title,
              style: titleStyle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 4),
          Text(
            metadata,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              height: 1,
              color: theme.colorScheme.outline,
            ),
          ),
          if (videoItem.isLive != true) ...[
            _compactStat(theme, StatType.play, videoItem.stat.view),
            _compactStat(theme, StatType.danmaku, videoItem.stat.danmu),
          ],
        ],
      ),
    );
  }

  Widget _compactStat(ThemeData theme, StatType type, int? value) {
    final color = theme.colorScheme.outline.withValues(alpha: .8);
    return Row(
      spacing: 2,
      children: [
        Icon(type.iconData, semanticLabel: type.label, size: 13, color: color),
        Expanded(
          child: Text(
            NumUtils.numFormat(value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, height: 1.25, color: color),
          ),
        ),
      ],
    );
  }

  Widget content(ThemeData theme) {
    String pubdate = DateFormatUtils.dateFormat(videoItem.pubdate!);
    if (pubdate != '') pubdate += '  ';
    return Expanded(
      child: Column(
        crossAxisAlignment: .start,
        children: [
          if (videoItem.titleList?.isNotEmpty == true)
            Expanded(
              child: Text.rich(
                overflow: .ellipsis,
                maxLines: 2,
                TextSpan(
                  children: videoItem.titleList!
                      .map(
                        (e) => TextSpan(
                          text: e.text,
                          style: TextStyle(
                            fontSize: theme.textTheme.bodyMedium!.fontSize,
                            height: 1.42,
                            letterSpacing: 0.3,
                            color: e.isEm
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            )
          else
            Expanded(
              child: Text(
                videoItem.title,
                textAlign: .start,
                style: TextStyle(
                  fontSize: theme.textTheme.bodyMedium!.fontSize,
                  height: 1.42,
                  letterSpacing: 0.3,
                ),
                maxLines: 2,
                overflow: .ellipsis,
              ),
            ),
          Text(
            "$pubdate${videoItem.owner.name}",
            maxLines: 1,
            style: TextStyle(
              fontSize: 12,
              height: 1,
              color: theme.colorScheme.outline,
              overflow: .clip,
            ),
          ),
          if (videoItem.isLive != true) ...[
            const SizedBox(height: 3),
            Row(
              spacing: 8,
              children: [
                StatWidget(
                  type: .play,
                  value: videoItem.stat.view,
                ),
                StatWidget(
                  type: .danmaku,
                  value: videoItem.stat.danmu,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CoverBuilderH extends StatefulWidget {
  const _CoverBuilderH({
    required this.cover,
    required this.badge,
    required this.duration,
    this.progress,
    required this.colorScheme,
  });

  final String? cover;
  final String? badge;
  final int duration;
  final num? progress;
  final ColorScheme colorScheme;

  @override
  State<_CoverBuilderH> createState() => _CoverBuilderHState();
}

class _CoverBuilderHState extends State<_CoverBuilderH> {
  BoxConstraints? _previousConstraints;
  Widget? _cachedChild;

  late final Widget Function(BuildContext, BoxConstraints) _builder = _build;

  Widget _build(BuildContext context, BoxConstraints constraints) {
    if (_cachedChild != null && constraints == _previousConstraints) {
      return _cachedChild!;
    }
    _previousConstraints = constraints;
    final double maxWidth = constraints.maxWidth;
    final double maxHeight = constraints.maxHeight;
    _cachedChild = Stack(
      clipBehavior: Clip.none,
      children: [
        NetworkImgLayer(
          src: widget.cover,
          width: maxWidth,
          height: maxHeight,
        ),
        if (widget.badge != null)
          PBadge(
            text: widget.badge,
            top: 6.0,
            right: 6.0,
            type: switch (widget.badge!) {
              '充电专属' => PBadgeType.error,
              _ => PBadgeType.primary,
            },
          ),
        if (widget.progress != null && widget.progress != 0) ...[
          PBadge(
            text: widget.progress == -1
                ? '已看完'
                : '${DurationUtils.formatDuration(widget.progress!)}/${DurationUtils.formatDuration(widget.duration)}',
            right: 6,
            bottom: 8,
            type: PBadgeType.gray,
          ),
          Positioned(
            left: 0,
            bottom: 3,
            right: 0,
            child: VideoProgressIndicator(
              color: widget.colorScheme.primary,
              backgroundColor: widget.colorScheme.secondaryContainer,
              progress: widget.progress == -1
                  ? 1
                  : widget.progress! / widget.duration,
            ),
          ),
        ] else if (widget.duration > 0)
          PBadge(
            text: DurationUtils.formatDuration(widget.duration),
            right: 6.0,
            bottom: 6.0,
            type: PBadgeType.gray,
          ),
      ],
    );
    return _cachedChild!;
  }

  @override
  void didUpdateWidget(_CoverBuilderH oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cover != widget.cover ||
        oldWidget.badge != widget.badge ||
        oldWidget.duration != widget.duration ||
        oldWidget.progress != widget.progress) {
      _cachedChild = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: _builder);
  }
}

Future<void> pushVideoH(HorizontalVideoModel videoItem) async {
  if (videoItem.isPugv ?? false) {
    PageUtils.viewPugv(seasonId: videoItem.seasonId);
    return;
  }

  if (videoItem.isLive ?? false) {
    if (videoItem.roomId case final roomId?) {
      PageUtils.toLiveRoom(roomId);
    }
    return;
  }

  if (videoItem.redirectUrl?.isNotEmpty == true &&
      PageUtils.viewPgcFromUri(videoItem.redirectUrl!)) {
    return;
  }

  int? cid = videoItem.cid;
  Dimension? dimension = videoItem.dimension;
  if (cid == null) {
    if (await SearchHttp.ab2cWithDimension(
          aid: videoItem.aid,
          bvid: videoItem.bvid,
        )
        case final res?) {
      cid = res.cid;
      dimension = res.dimension;
    }
  }
  if (cid != null) {
    PageUtils.toVideoPage(
      bvid: videoItem.bvid,
      cid: cid,
      cover: videoItem.cover,
      title: videoItem.title,
      dimension: dimension,
    );
  }
}
