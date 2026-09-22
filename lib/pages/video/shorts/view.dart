import 'dart:async';
import 'chrome.dart';
import 'dart:math' as math;
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/progress_bar/audio_video_progress_bar.dart';
import 'package:PiliPlus/pages/video/controller.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/controller.dart';
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
  @override
  State<ShortVideoFeed> createState() => _ShortVideoFeedState();
}

class _ShortVideoFeedState extends State<ShortVideoFeed> {
  ShortVideoSession get session => widget.session;
  Timer? _warmTimer;
  Worker? _bufferWatch;
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
    final index = (_targetIndex ?? session.index).clamp(
      0,
      session.entries.length - 1,
    );
    widget.video.preloadShortWindow([
      if (index != session.index) session.entries[index],
      ...session.entries.skip(index + 1).take(3),
    ]);
  }

  @override
  void initState() {
    super.initState();
    session.addListener(_changed);
    widget.video.plPlayerController.addStatusLister(_statusChanged);
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
    session.removeListener(_changed);
    widget.video.plPlayerController.removeStatusLister(_statusChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Material(
        color: Colors.black,
        child: LayoutBuilder(
          builder: (context, bounds) {
            return SafeArea(
              child: ShortCommentsLayout(
                panel: widget.commentsPanel,
                builder: (context, compact) => Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: bounds.maxWidth >= 720 || widget.fullscreen
                          ? double.infinity
                          : 600,
                    ),
                    child: LayoutBuilder(
                      builder: (context, pane) => Obx(
                        () => ShortVideoPager(
                          session: session,
                          onTargetChanged: (index) {
                            _targetIndex = index;
                            _warmWindow();
                          },
                          enabled:
                              !compact &&
                              !widget
                                  .video
                                  .plPlayerController
                                  .controlsLock
                                  .value,
                          onError: (message) => SmartDialog.showToast(message),
                          builder: (context, index, active) {
                            if (active)
                              return _currentPage(pane, compact: compact);
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                if (session.entries[index].cover
                                    case final cover?)
                                  Padding(
                                    padding: EdgeInsets.only(
                                      bottom: widget.fullscreen
                                          ? 0
                                          : ShortVideoControls.heightFor(
                                              MediaQuery.textScalerOf(context),
                                            ),
                                    ),
                                    child: LayoutBuilder(
                                      builder: (_, media) => NetworkImgLayer(
                                        src: cover,
                                        fit: BoxFit.contain,
                                        borderRadius: BorderRadius.zero,
                                        width: media.maxWidth,
                                        height: media.maxHeight,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
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
    label: '$action $label',
    selected: selected,
    child: InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: selected ? const Color(0xFFFB7299) : Colors.white,
              size: 32,
              shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
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

  Widget _currentPage(BoxConstraints pane, {bool compact = false}) {
    if (compact) return widget.playerBuilder(pane.maxWidth, pane.maxHeight);
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
    final bottomHeight = ShortVideoControls.heightFor(
      MediaQuery.textScalerOf(context),
    );
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
                  widget.video.shortChromeVisible.value &&
                  !player.isSeeking.value,
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
                          tooltip: '返回',
                          onPressed: Get.back,
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                        ),
                        Expanded(
                          child: Obx(
                            () => Text(
                              '${widget.intro.total.value} 人正在看',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '搜索',
                          onPressed: () => Get.toNamed('/search'),
                          icon: const Icon(Icons.search, color: Colors.white),
                        ),
                        widget.moreButton ??
                            IconButton(
                              tooltip: '更多',
                              onPressed: widget.onMore,
                              icon: const Icon(
                                Icons.more_vert,
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
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 6,
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
                          String count(num? value, String fallback) =>
                              value == null
                              ? fallback
                              : NumUtils.numFormat(value);
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _action(
                                icon: Icons.thumb_up_rounded,
                                action: '点赞',
                                label: count(stat?.like, '点赞'),
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
                                label: count(stat?.reply, '评论'),
                                onTap: ready ? widget.onComments : null,
                              ),
                              _action(
                                icon: Icons.monetization_on_outlined,
                                action: '投币',
                                label: count(stat?.coin, '投币'),
                                selected:
                                    ready && widget.intro.coinNum.value > 0,
                                onTap: ready
                                    ? widget.intro.actionCoinVideo
                                    : null,
                              ),
                              _action(
                                icon: Icons.star_rounded,
                                action: '收藏',
                                label: count(stat?.favorite, '收藏'),
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
                                label: count(stat?.share, '分享'),
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
                    left: 12,
                    right: 68,
                    bottom: bottomHeight + 12,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: math.max(60, pane.maxHeight * .36),
                      ),
                      child: SingleChildScrollView(
                        child: Obx(() {
                          final detail = widget.intro.videoDetail.value;
                          final ready =
                              detail.bvid == session.current.bvid &&
                              !session.switching;
                          final owner = ready ? detail.owner : null;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  if (owner?.face case final face?)
                                    GestureDetector(
                                      onTap: () => Get.toNamed(
                                        '/member?mid=${owner!.mid}',
                                      ),
                                      child: NetworkImgLayer(
                                        src: face,
                                        width: 40,
                                        height: 40,
                                        type: .avatar,
                                      ),
                                    ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: InkWell(
                                      onTap: owner?.mid == null
                                          ? null
                                          : () => Get.toNamed(
                                              '/member?mid=${owner!.mid}',
                                            ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            owner?.name ?? '',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
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
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (ready && owner != null)
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFDB4C7F,
                                        ),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        minimumSize: const Size(0, 30),
                                      ),
                                      onPressed: () => widget.intro
                                          .actionRelationMod(context),
                                      child: Text(
                                        (widget
                                                        .intro
                                                        .followStatus
                                                        .value
                                                        .attribute ??
                                                    0) ==
                                                0
                                            ? '+ 关注'
                                            : '已关注',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              GestureDetector(
                                onTap: widget.onDetails,
                                child: Text(
                                  ready
                                      ? detail.title ?? ''
                                      : session.current.title ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    shadows: [
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
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              if (ready &&
                                  (detail.ugcSeason != null ||
                                      (detail.pages?.length ?? 0) > 1))
                                TextButton.icon(
                                  onPressed: widget.onEpisodes,
                                  icon: const Icon(
                                    Icons.video_library_outlined,
                                    color: Colors.white70,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    '合集 / 分 P',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
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
        Positioned(
          left: 12,
          right: 12,
          bottom: 0,
          child: SizedBox(
            height:
                48 +
                ShortVideoMinimalControls.heightFor(
                  MediaQuery.textScalerOf(context),
                ),
            child: Column(
              children: [
                Obx(
                  () => ShortVideoMinimalControls(
                    playing: player.playerStatus.isPlaying,
                    showPlayback: !widget.video.shortChromeVisible.value,
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
                      barHeight: player.isSeeking.value ? 4 : 2,
                      thumbRadius: player.isSeeking.value ? 6 : 2,
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
