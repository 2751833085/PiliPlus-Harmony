import 'package:PiliPlus/harmony_adapt/widgets/cover_hero.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/badge.dart';
import 'package:PiliPlus/common/widgets/image/image_save.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/stat/stat.dart';
import 'package:PiliPlus/common/widgets/video_popup_menu.dart';
import 'package:PiliPlus/http/search.dart';
import 'package:PiliPlus/models/common/badge_type.dart';
import 'package:PiliPlus/models/common/stat_type.dart';
import 'package:PiliPlus/models/home/rcmd/result.dart';
import 'package:PiliPlus/models/model_rec_video_item.dart';
import 'package:PiliPlus/models_new/video/video_detail/dimension.dart';
import 'package:PiliPlus/utils/app_scheme.dart';
import 'package:PiliPlus/utils/date_utils.dart';
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:PiliPlus/utils/extension/dimension_ext.dart';
import 'package:PiliPlus/utils/id_utils.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:intl/intl.dart';

// 视频卡片 - 垂直布局
class VideoCardV extends StatelessWidget {
  final BaseRcmdVideoItemModel videoItem;
  final VoidCallback? onRemove;

  const VideoCardV({
    super.key,
    required this.videoItem,
    this.onRemove,
  });

  Future<void> onPushDetail(String? heroTag) async {
    switch (videoItem.goto) {
      case 'bangumi':
        PageUtils.viewPgc(epId: videoItem.param!, heroTag: heroTag);
        break;
      case 'av':
        var bvid = videoItem.bvid ?? IdUtils.av2bv(videoItem.aid!);
        var cid = videoItem.cid;
        bool isVertical = false;
        Dimension? dimension = videoItem.dimension;
        if (videoItem is RcmdVideoItemAppModel) {
          if (videoItem.uri case final uri?) {
            isVertical = uri.isVerticalFromUri;
          }
        }
        if (cid == null) {
          if (await SearchHttp.ab2cWithDimension(aid: videoItem.aid, bvid: bvid)
              case final res?) {
            cid = res.cid;
            dimension = res.dimension;
          }
        }
        if (cid != null) {
          PageUtils.toVideoPage(
            aid: videoItem.aid,
            bvid: bvid,
            cid: cid,
            cover: videoItem.cover,
            title: videoItem.title,
            isVertical: isVertical,
            dimension: dimension,
            heroTag: heroTag,
          );
        }
        break;
      // 动态
      case 'picture':
        try {
          PiliScheme.routePushFromUrl(videoItem.uri!);
        } catch (err) {
          SmartDialog.showToast(err.toString());
        }
        break;
      default:
        if (videoItem.uri?.isNotEmpty == true) {
          PiliScheme.routePushFromUrl(videoItem.uri!);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    void onLongPress() => imageSaveDialog(
      title: videoItem.title,
      cover: videoItem.cover,
      bvid: videoItem.bvid,
    );
    final heroTag = Pref.enableHeroCoverAnimation
        ? videoItem.goto == 'bangumi'
              ? 'pgc_hero_${videoItem.param}'
              : 'video_hero_${videoItem.cid ?? videoItem.aid ?? videoItem.param}'
        : null;
    Widget card = Card(
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () => onPushDetail(heroTag),
        onLongPress: onLongPress,
        onSecondaryTap: PlatformUtils.isMobile ? null : onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoverHero(
              tag: heroTag,
              cover: videoItem.cover,
              aspectRatio: Style.aspectRatio,
              child: _CoverBuilder(
                cover: videoItem.cover,
                duration: videoItem.duration,
                shortVideo: Pref.shortVideoMode && videoItem.isPortraitVideo,
              ),
            ),
            content(context),
          ],
        ),
      ),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        card,
        if (videoItem.goto == 'av')
          Positioned(
            right: -5,
            bottom: -2,
            width: 29,
            height: 29,
            child: VideoPopupMenu(
              iconSize: 17,
              videoItem: videoItem,
              onRemove: onRemove,
            ),
          ),
      ],
    );
  }

  Widget content(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                "${videoItem.title}\n",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  height: 1.38,
                ),
              ),
            ),
            videoStat(context, theme),
            Row(
              spacing: 2,
              children: [
                if (videoItem.goto == 'bangumi')
                  PBadge(
                    text: videoItem.pgcBadge,
                    isStack: false,
                    size: .small,
                    type: .line_primary,
                    fontSize: 9,
                  ),
                if (videoItem.rcmdReason != null)
                  PBadge(
                    text: videoItem.rcmdReason,
                    isStack: false,
                    size: .small,
                    type: .secondary,
                  ),
                if (videoItem.goto == 'picture')
                  const PBadge(
                    text: '动态',
                    isStack: false,
                    size: .small,
                    type: .line_primary,
                    fontSize: 9,
                  ),
                if (videoItem.isFollowed)
                  const PBadge(
                    text: '已关注',
                    isStack: false,
                    size: .small,
                    type: .secondary,
                  ),
                Expanded(
                  flex: 1,
                  child: Text(
                    videoItem.owner.name.toString(),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    semanticsLabel: 'UP：${videoItem.owner.name}',
                    style: TextStyle(
                      height: 1.5,
                      fontSize: theme.textTheme.labelMedium!.fontSize,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
                if (videoItem.goto == 'av') const SizedBox(width: 10),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static final shortFormat = DateFormat('M-d');
  static final longFormat = DateFormat('yy-M-d');

  Widget videoStat(BuildContext context, ThemeData theme) {
    return Row(
      children: [
        StatWidget(
          type: StatType.play,
          value: videoItem.stat.view,
        ),
        if (videoItem.goto != 'picture') ...[
          const SizedBox(width: 4),
          StatWidget(
            type: StatType.danmaku,
            value: videoItem.stat.danmu,
          ),
        ],
        if (videoItem is RcmdVideoItemModel) ...[
          const Spacer(),
          Text(
            DateFormatUtils.dateFormat(
              videoItem.pubdate,
              short: shortFormat,
              long: longFormat,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: theme.textTheme.labelSmall!.fontSize,
              color: theme.colorScheme.outline.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(width: 2),
        ],
        // deprecated
        //  else if (videoItem is RcmdVideoItemAppModel &&
        //     videoItem.desc != null &&
        //     videoItem.desc!.contains(' · ')) ...[
        //   const Spacer(),
        //   Text.rich(
        //     maxLines: 1,
        //     TextSpan(
        //         style: TextStyle(
        //           fontSize: theme.textTheme.labelSmall!.fontSize,
        //           color: theme.colorScheme.outline.withValues(alpha: 0.8),
        //         ),
        //         text: Utils.shortenChineseDateString(
        //             videoItem.desc!.split(' · ').last)),
        //   ),
        //   const SizedBox(width: 2),
        // ]
      ],
    );
  }
}

class _CoverBuilder extends StatelessWidget {
  const _CoverBuilder({
    required this.cover,
    required this.duration,
    required this.shortVideo,
  });

  final String? cover;
  final int duration;
  final bool shortVideo;

  // 缓存 builder 闭包，避免每次 rebuild 产生新实例触发 scheduleLayoutCallback
  static Widget _buildCover(
    BuildContext context,
    BoxConstraints constraints,
    String? cover,
    int duration,
    bool shortVideo,
  ) {
    final double maxWidth = constraints.maxWidth;
    final double maxHeight = constraints.maxHeight;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        NetworkImgLayer(
          src: cover,
          width: maxWidth,
          height: maxHeight,
          borderRadius: BorderRadius.zero,
        ),
        if (shortVideo)
          const Positioned(
            top: 7,
            right: 7,
            child: Tooltip(
              message: '以短视频模式打开',
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                  child: Icon(
                    Icons.stay_current_portrait_rounded,
                    size: 17,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        if (duration > 0)
          PBadge(
            bottom: 6,
            right: 7,
            size: PBadgeSize.small,
            type: PBadgeType.gray,
            text: DurationUtils.formatDuration(duration),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return _CachedLayoutBuilder(
      cover: cover,
      duration: duration,
      shortVideo: shortVideo,
    );
  }
}

class _CachedLayoutBuilder extends StatefulWidget {
  const _CachedLayoutBuilder({
    required this.cover,
    required this.duration,
    required this.shortVideo,
  });

  final String? cover;
  final int duration;
  final bool shortVideo;

  @override
  State<_CachedLayoutBuilder> createState() => _CachedLayoutBuilderState();
}

class _CachedLayoutBuilderState extends State<_CachedLayoutBuilder> {
  BoxConstraints? _previousConstraints;
  Widget? _cachedChild;

  // 稳定的闭包实例，不会因父 rebuild 而改变
  late final Widget Function(BuildContext, BoxConstraints) _builder = _build;

  Widget _build(BuildContext context, BoxConstraints constraints) {
    // 约束未变时直接返回缓存，跳过子树重建
    if (_cachedChild != null && constraints == _previousConstraints) {
      return _cachedChild!;
    }
    _previousConstraints = constraints;
    _cachedChild = _CoverBuilder._buildCover(
      context,
      constraints,
      widget.cover,
      widget.duration,
      widget.shortVideo,
    );
    return _cachedChild!;
  }

  @override
  void didUpdateWidget(_CachedLayoutBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 数据源变化时清除缓存，强制下次重建
    if (oldWidget.cover != widget.cover ||
        oldWidget.duration != widget.duration ||
        oldWidget.shortVideo != widget.shortVideo) {
      _cachedChild = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: Style.aspectRatio,
      child: LayoutBuilder(builder: _builder),
    );
  }
}
