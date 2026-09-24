import 'package:PiliPlus/pages/video/shorts/preview_chrome.dart';
import 'package:PiliPlus/pages/video/shorts/episodes.dart';
import 'dart:async';
import 'dart:convert';
import 'chrome.dart';
import 'metrics.dart';
import 'dart:math' as math;
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/progress_bar/audio_video_progress_bar.dart';
import 'package:PiliPlus/pages/video/controller.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/controller.dart';
import 'package:PiliPlus/pages/video/widgets/header_mixin.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/pages/video/shorts/search_suggestion.dart';
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:PiliPlus/utils/num_utils.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';
import 'session.dart';
import 'pager.dart';
import 'controls.dart';
import 'comments_layout.dart';
import 'package:PiliPlus/plugin/pl_player/models/play_status.dart';

class ShortVideoFeed extends StatefulWidget {
  const ShortVideoFeed({
    super.key,
    required this.session,
    required this.video,
    required this.intro,
    required this.playerBuilder,
    required this.onDetails,
    required this.onComments,
    required this.onEpisodes,
    required this.onMore,
    required this.fullscreen,
    this.moreButton,
    this.onPlay,
    this.commentsPanel,
    this.onDanmakuSettings,
    this.onSearch,
  });
  final ShortVideoSession session;
  final VideoDetailController video;
  final UgcIntroController intro;
  final Widget Function(double width, double height) playerBuilder;
  final VoidCallback onDetails, onComments, onEpisodes, onMore;
  final bool fullscreen;
  final Widget? moreButton;
  final VoidCallback? onPlay;
  final Widget? commentsPanel;
  final VoidCallback? onDanmakuSettings;
  final ValueChanged<String>? onSearch;
  @override
  State<ShortVideoFeed> createState() => _ShortVideoFeedState();
}

class _ShortVideoFeedState extends State<ShortVideoFeed>
    with HeaderMixin<ShortVideoFeed> {
  @override
  PlPlayerController get plPlayerController => widget.video.plPlayerController;
  ShortVideoSession get session => widget.session;
  Timer? _warmTimer;
  Worker? _bufferWatch;
  Worker? _previewWatch;
  int? _targetIndex;
  void _warmNext() {
    if (_warmTimer != null) return;
    _warmTimer = Timer(const Duration(milliseconds: 80), () {
      _warmTimer = null;
      if (!mounted || session.refreshing) return;
      _warmWindow();
    });
  }

  void _warmWindow() {
    final entries = session.entries;
    final index = (_targetIndex ?? session.index).clamp(
      0,
      entries.length - 1,
    );
    // Buffered-byte updates only warm the next sources. Preview changes have
    // their own revision listener; rebuilding here also rebuilds the live page.
    unawaited(
      widget.video.preloadShortWindow([
        if (index != session.index) entries[index],
        ...entries.skip(index + 1).take(3),
        if (index > 0) entries[index - 1],
      ]),
    );
  }

  @override
  void initState() {
    super.initState();
    session.addListener(_changed);
    widget.video.plPlayerController.addStatusLister(_statusChanged);
    _previewWatch = ever(widget.video.shortPreviewRevision, (_) {
      if (mounted) setState(() {});
    });
    _bufferWatch = everAll([
      widget.video.plPlayerController.isBuffering,
      widget.video.plPlayerController.buffered,
    ], (_) => _warmNext());
  }

  void _changed() {
    if (mounted) {
      if (!session.switching && _targetIndex == session.index)
        _targetIndex = null;
      setState(() {});
      _warmNext();
    }
  }

  void _statusChanged(PlayerStatus _) => _changed();
  @override
  void dispose() {
    _warmTimer?.cancel();
    _bufferWatch?.dispose();
    _previewWatch?.dispose();
    session.removeListener(_changed);
    widget.video.plPlayerController.removeStatusLister(_statusChanged);
    super.dispose();
  }

  String? _lastViewportDiagnostic;

  // Opt-in local diagnostics contain geometry only, never account/video data.
  void _recordViewport(BuildContext context, BoxConstraints bounds) {
    if (!const bool.fromEnvironment('HARMONY_LAYOUT_DIAGNOSTICS')) return;
    final view = View.of(context);
    final media = MediaQuery.of(context);
    final record = jsonEncode({
      'physical_size_px': [view.physicalSize.width, view.physicalSize.height],
      'engine_dpr': view.devicePixelRatio,
      'effective_dpr': media.devicePixelRatio,
      'app_ui_scale': media.devicePixelRatio / view.devicePixelRatio,
      'text_scale_at_14': media.textScaler.scale(14) / 14,
      'logical_size': [media.size.width, media.size.height],
      'layout_size': [bounds.maxWidth, bounds.maxHeight],
      'safe_insets_logical': [
        media.padding.left,
        media.padding.top,
        media.padding.right,
        media.padding.bottom,
      ],
    });
    if (record == _lastViewportDiagnostic) return;
    _lastViewportDiagnostic = record;
    debugPrint('PiliPlusDisplayMetrics $record');
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Material(
        color: Colors.black,
        child: LayoutBuilder(
          builder: (context, bounds) {
            _recordViewport(context, bounds);
            return SafeArea(
              child: ShortCommentsLayout(
                panel: widget.commentsPanel,
                builder: (context, compact) => LayoutBuilder(
                  builder: (context, pane) => Obx(
                    () => ShortVideoPager(
                      session: session,
                      onTargetChanged: (index) {
                        _targetIndex = index;
                        _warmNext();
                      },
                      enabled:
                          !widget.video.plPlayerController.controlsLock.value,
                      onError: (message) => SmartDialog.showToast(message),
                      builder: (context, index, active) {
                        if (active) return _currentPage(pane, compact: compact);
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            if (widget.video.preloadedFirstFrame(
                                      session.entries[index].bvid,
                                      cid: session.entries[index].cid,
                                    ) ??
                                    session.entries[index].cover
                                case final cover?)
                              Padding(
                                padding: EdgeInsets.only(
                                  bottom: widget.fullscreen
                                      ? 0
                                      : ShortVideoMetrics.of(
                                          context,
                                        ).footerHeight,
                                ),
                                child: LayoutBuilder(
                                  builder: (_, media) => NetworkImgLayer(
                                    maxDecodeDimension: 960,
                                    src: cover,
                                    getPlaceHolder: () =>
                                        const SizedBox.expand(),
                                    fit: BoxFit.contain,
                                    borderRadius: BorderRadius.zero,
                                    width: media.maxWidth,
                                    height: media.maxHeight,
                                  ),
                                ),
                              ),
                            if (!widget.fullscreen &&
                                (index != session.index || session.switching))
                              Obx(
                                () => ShortPreviewChrome(
                                  title: session.entries[index].title ?? '',
                                  showDetails:
                                      widget.video.shortChromeVisible.value &&
                                      !compact,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _action({
    required IconData icon,
    required String label,
    required String action,
    required VoidCallback? onTap,
    bool selected = false,
    VoidCallback? onLongPress,
  }) => Semantics(
    button: true,
    label: label.isEmpty ? action : '$action $label',
    excludeSemantics: true,
    enabled: onTap != null,
    onTap: onTap,
    onLongPress: onLongPress,
    selected: selected,
    child: InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: ShortVideoMetrics.actionWidth,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: selected ? const Color(0xFFFB7299) : Colors.white,
              size: ShortVideoMetrics.of(context).actionIcon,
              shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              height: ShortVideoMetrics.of(context).captionHeight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: ShortVideoMetrics.caption.copyWith(
                    color: Colors.white,
                    shadows: const [
                      Shadow(color: Colors.black87, blurRadius: 4),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  void _togglePlayback() {
    if (widget.onPlay != null) {
      widget.onPlay!();
    } else {
      widget.video.plPlayerController.onDoubleTapCenter();
    }
  }

  bool get _pausedPresentation {
    final player = widget.video.plPlayerController;
    return player.playerStatus.isPaused &&
        !session.switching &&
        player.duration.value > 0 &&
        !player.isBuffering.value;
  }

  Widget _currentPage(BoxConstraints pane, {bool compact = false}) {
    final player = widget.video.plPlayerController;
    if (widget.fullscreen)
      return Stack(
        fit: StackFit.expand,
        children: [
          widget.playerBuilder(pane.maxWidth, pane.maxHeight),
          Positioned(
            right: 16,
            bottom: 76,
            child: Obx(
              () => !player.controlsLock.value && player.showControls.value
                  ? FilledButton.tonalIcon(
                      onPressed: widget.onComments,
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('评论'),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          if (session.refreshing)
            const Positioned(
              top: 56,
              left: 0,
              right: 0,
              child: Center(
                child: Text('正在刷新视频列表', style: TextStyle(color: Colors.white)),
              ),
            ),
        ],
      );
    final metrics = ShortVideoMetrics.of(context);
    final bottomHeight = metrics.footerHeight;
    return Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: bottomHeight),
          child: widget.playerBuilder(
            pane.maxWidth,
            math.max(1, pane.maxHeight - bottomHeight),
          ),
        ),
        Positioned.fill(
          child: Obx(
            () => ShortVideoChrome(
              visible:
                  !player.isSeeking.value &&
                  widget.video.shortChromeVisible.value &&
                  !compact,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black54,
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black87,
                          ],
                          stops: [0, .2, .6, 1],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 4,
                    right: 4,
                    child: Row(
                      children: [
                        IconButton(
                          style: metrics.iconButtonStyle,
                          tooltip: '返回',
                          onPressed: Get.back,
                          icon: Icon(
                            Icons.arrow_back,
                            size: metrics.icon,
                            color: Colors.white,
                          ),
                        ),
                        Expanded(
                          child: Obx(
                            () => Text(
                              '${widget.intro.total.value} 人正在看',
                              style: ShortVideoMetrics.caption,
                            ),
                          ),
                        ),
                        IconButton(
                          style: metrics.iconButtonStyle,
                          tooltip: '搜索',
                          onPressed: () => Get.toNamed('/search'),
                          icon: Icon(
                            Icons.search,
                            size: metrics.icon,
                            color: Colors.white,
                          ),
                        ),
                        widget.moreButton ??
                            IconButton(
                              style: metrics.iconButtonStyle,
                              tooltip: '更多',
                              onPressed: widget.onMore,
                              icon: Icon(
                                Icons.more_vert,
                                size: metrics.icon,
                                color: Colors.white,
                              ),
                            ),
                      ],
                    ),
                  ),
                  if (session.refreshing ||
                      (!session.hasNext &&
                          (session.loading || session.error != null)))
                    Positioned(
                      top: 52,
                      left: 16,
                      right: 16,
                      child: Center(
                        child: TextButton(
                          onPressed: session.loading || session.refreshing
                              ? null
                              : session.loadMore,
                          child: Text(
                            session.refreshing
                                ? '正在刷新视频列表'
                                : session.loading
                                ? '正在获取更多视频'
                                : session.error!,
                            style: ShortVideoMetrics.caption,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 4,
                    bottom: bottomHeight + 20,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: math.max(
                          80,
                          pane.maxHeight - bottomHeight - 80,
                        ),
                      ),
                      child: SingleChildScrollView(
                        child: Obx(() {
                          final detail = widget.intro.videoDetail.value;
                          final ready =
                              detail.bvid == session.current.bvid &&
                              !session.switching;
                          final stat = ready ? detail.stat : null;
                          String count(num? value) =>
                              value == null ? '' : NumUtils.numFormat(value);
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _action(
                                icon: Icons.thumb_up_rounded,
                                action: '点赞',
                                label: count(stat?.like),
                                selected: ready && widget.intro.hasLike.value,
                                onTap: ready
                                    ? () => session.interact(
                                        () => widget.intro.handleAction(
                                          widget.intro.actionLikeVideo,
                                        ),
                                      )
                                    : null,
                                onLongPress: ready
                                    ? () => session.interact(
                                        () => widget.intro.handleAction(
                                          widget.intro.actionTriple,
                                        ),
                                      )
                                    : null,
                              ),
                              _action(
                                icon: Icons.chat_bubble_rounded,
                                action: '评论',
                                label: count(stat?.reply),
                                onTap: ready ? widget.onComments : null,
                              ),
                              _action(
                                icon: Icons.monetization_on_outlined,
                                action: '投币',
                                label: count(stat?.coin),
                                selected:
                                    ready && widget.intro.coinNum.value > 0,
                                onTap: ready
                                    ? widget.intro.actionCoinVideo
                                    : null,
                              ),
                              _action(
                                icon: Icons.star_rounded,
                                action: '收藏',
                                label: count(stat?.favorite),
                                selected: ready && widget.intro.hasFav.value,
                                onTap: ready
                                    ? () => session.interact(() async {
                                        if (widget.intro.enableQuickFav) {
                                          await widget.intro.actionFavVideo(
                                            isQuick: true,
                                          );
                                        } else {
                                          widget.intro.showFavBottomSheet(
                                            context,
                                          );
                                        }
                                      })
                                    : null,
                                onLongPress: ready
                                    ? () => widget.intro.showFavBottomSheet(
                                        context,
                                        isLongPress: true,
                                      )
                                    : null,
                              ),
                              _action(
                                icon: Icons.reply_rounded,
                                action: '分享',
                                label: count(stat?.share),
                                onTap: ready
                                    ? () =>
                                          widget.intro.actionShareVideo(context)
                                    : null,
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
                  Positioned(
                    left: ShortVideoMetrics.gutter,
                    right: ShortVideoMetrics.informationRight,
                    bottom: bottomHeight + 12,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: math.max(60, pane.maxHeight * .42),
                      ),
                      child: SingleChildScrollView(
                        child: Obx(() {
                          final detail = widget.intro.videoDetail.value;
                          final ready =
                              detail.bvid == session.current.bvid &&
                              !session.switching;
                          final owner = ready ? detail.owner : null;
                          final searchTerm = ready
                              ? shortVideoSearchTerm(
                                  tags: widget.intro.videoTags.value,
                                  title: detail.title,
                                )
                              : null;
                          final hasEpisodes =
                              ready && !ShortVideoEpisodes(detail).isEmpty;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (owner != null)
                                    GestureDetector(
                                      onTap: () => Get.toNamed(
                                        '/member?mid=${owner.mid}',
                                      ),
                                      child: NetworkImgLayer(
                                        key: const ValueKey(
                                          'short-author-avatar',
                                        ),
                                        src: owner.face,
                                        width: metrics.avatar,
                                        height: metrics.avatar,
                                        type: .avatar,
                                      ),
                                    ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: InkWell(
                                      key: const ValueKey('short-author-info'),
                                      onTap: owner?.mid == null
                                          ? null
                                          : () => Get.toNamed(
                                              '/member?mid=${owner!.mid}',
                                            ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            owner?.name ?? '',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: ShortVideoMetrics.author,
                                          ),
                                          if (ready &&
                                              widget
                                                      .intro
                                                      .userStat
                                                      .value
                                                      .follower !=
                                                  null)
                                            Text(
                                              '${NumUtils.numFormat(widget.intro.userStat.value.follower!)} 粉丝',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: ShortVideoMetrics.caption,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (ready && owner != null) ...[
                                    const SizedBox(
                                      width: ShortVideoMetrics.gap,
                                    ),
                                    ShortVideoPillButton(
                                      key: const ValueKey('short-follow'),
                                      color:
                                          (widget
                                                      .intro
                                                      .followStatus
                                                      .value
                                                      .attribute ??
                                                  0) ==
                                              0
                                          ? const Color(0xFFDB4C7F)
                                          : const Color(0xFF303135),
                                      foreground: Colors.white,
                                      centered: true,
                                      onPressed: () => widget.intro
                                          .actionRelationMod(context),
                                      label:
                                          (widget
                                                      .intro
                                                      .followStatus
                                                      .value
                                                      .attribute ??
                                                  0) ==
                                              0
                                          ? '+ 关注'
                                          : '已关注',
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: widget.onDetails,
                                child: Text(
                                  ready
                                      ? detail.title ?? ''
                                      : session.current.title ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: ShortVideoMetrics.body.copyWith(
                                    shadows: const [
                                      Shadow(
                                        color: Colors.black,
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (ready)
                                Text(
                                  '${NumUtils.numFormat(detail.stat?.view ?? 0)} 次播放',
                                  style: ShortVideoMetrics.caption,
                                ),
                              if (searchTerm != null || hasEpisodes) ...[
                                const SizedBox(height: 10),
                                ShortVideoContextRow(
                                  search: searchTerm == null
                                      ? null
                                      : ShortVideoContextLink(
                                          key: const ValueKey(
                                            'short-related-search',
                                          ),
                                          icon: Icons.search,
                                          compact: hasEpisodes,
                                          label: hasEpisodes
                                              ? searchTerm
                                              : '搜索 · $searchTerm',
                                          onTap: () {
                                            if (widget.onSearch
                                                case final onSearch?) {
                                              onSearch(searchTerm);
                                            } else {
                                              Get.toNamed(
                                                '/searchResult',
                                                parameters: {
                                                  'keyword': searchTerm,
                                                },
                                              );
                                            }
                                          },
                                        ),
                                  episodes: !hasEpisodes
                                      ? null
                                      : ShortVideoContextLink(
                                          key: const ValueKey('short-episodes'),
                                          icon: Icons.video_library_outlined,
                                          compact: searchTerm != null,
                                          label: searchTerm != null
                                              ? '合集/分P'
                                              : '合集 / 分 P',
                                          onTap: widget.onEpisodes,
                                        ),
                                ),
                              ],
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          bottom: bottomHeight,
          child: Obx(() {
            if (player.isSeeking.value ||
                compact ||
                !widget.video.shortChromeVisible.value ||
                !_pausedPresentation) {
              return const SizedBox.shrink();
            }
            final smallPlayer = pane.maxHeight - bottomHeight < 360;
            return Align(
              alignment: Alignment(0, smallPlayer ? -.4 : 0),
              child: ShortVideoPausedControls(
                compact: smallPlayer,
                time:
                    '${DurationUtils.formatDuration(player.progress)} / ${DurationUtils.formatDuration(player.duration.value)}',
                onResume: () => player.play(),
              ),
            );
          }),
        ),
        Positioned(
          left: ShortVideoMetrics.gutter,
          right: ShortVideoMetrics.gutter,
          bottom: 0,
          child: SizedBox(
            height:
                metrics.controlHeight +
                ShortVideoMinimalControls.heightFor(
                  MediaQuery.textScalerOf(context),
                ),
            child: Column(
              children: [
                Obx(
                  () => ShortVideoMinimalControls(
                    playing: player.playerStatus.isPlaying,
                    showPlayback:
                        compact || !widget.video.shortChromeVisible.value,
                    seeking: player.isSeeking.value,
                    time:
                        '${DurationUtils.formatDuration(player.progress)} / ${DurationUtils.formatDuration(player.duration.value)}',
                    onToggle: _togglePlayback,
                    progress: ProgressBar(
                      progress: player.progress,
                      buffered: player.buffered.value,
                      total: player.duration.value,
                      baseBarColor: Colors.white24,
                      progressBarColor: const Color(0xFFFB7299),
                      bufferedBarColor: Colors.white38,
                      thumbColor: Colors.white,
                      thumbGlowColor: Colors.white12,
                      barHeight: player.isSeeking.value
                          ? ShortVideoMetrics.activeTrack
                          : ShortVideoMetrics.track,
                      thumbRadius: player.isSeeking.value
                          ? ShortVideoMetrics.activeThumb
                          : ShortVideoMetrics.thumb,
                      thumbGlowRadius: ShortVideoMetrics.thumbGlow,
                      onDragStart: (value) => player.onSeekStart(value.seconds),
                      onDragUpdate: (value) =>
                          player.seekPosition.value = value.seconds,
                      onSeek: (milliseconds) {
                        player.position.value = milliseconds ~/ 1000;
                        player.onSeekEnd();
                        player.seekTo(
                          Duration(milliseconds: milliseconds),
                          isSeek: false,
                        );
                      },
                    ),
                  ),
                ),
                Obx(
                  () => ShortVideoChrome(
                    visible: !player.isSeeking.value,
                    child: ShortVideoControls(
                      danmaku: player.enableShowDanmaku.value,
                      onSend: widget.video.showShootDanmakuSheet,
                      onDanmaku: () => player.enableShowDanmaku.toggle(),
                      onDanmakuSettings:
                          widget.onDanmakuSettings ?? showSetDanmaku,
                      onDetails: widget.onDetails,
                      onFullscreen: () =>
                          player.triggerFullScreen(status: true),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
