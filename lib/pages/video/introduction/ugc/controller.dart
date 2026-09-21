import 'dart:async';
import 'dart:math';

import 'package:PiliPlus/common/widgets/button/icon_button.dart';
import 'package:PiliPlus/common/widgets/scroll_physics.dart';
import 'package:PiliPlus/http/api.dart';
import 'package:PiliPlus/http/ai_conclusion_request.dart';
import 'package:PiliPlus/http/constants.dart';
import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/member.dart';
import 'package:PiliPlus/http/search.dart';
import 'package:PiliPlus/http/user.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models/common/video/source_type.dart';
import 'package:PiliPlus/models_new/member_card_info/data.dart';
import 'package:PiliPlus/models_new/relation/data.dart';
import 'package:PiliPlus/models_new/video/video_ai_conclusion/model_result.dart';
import 'package:PiliPlus/models_new/video/video_detail/dimension.dart';
import 'package:PiliPlus/models_new/video/video_detail/episode.dart';
import 'package:PiliPlus/models_new/video/video_detail/page.dart';
import 'package:PiliPlus/models_new/video/video_detail/section.dart';
import 'package:PiliPlus/models_new/video/video_detail/staff.dart';
import 'package:PiliPlus/models_new/video/video_detail/stat_detail.dart';
import 'package:PiliPlus/models_new/video/video_detail/ugc_season.dart';
import 'package:PiliPlus/pages/common/common_intro_controller.dart';
import 'package:PiliPlus/pages/dynamics_repost/view.dart';
import 'package:PiliPlus/pages/video/related/controller.dart';
import 'package:PiliPlus/pages/video/reply/controller.dart';
import 'package:PiliPlus/plugin/pl_player/models/play_repeat.dart';
import 'package:PiliPlus/services/service_locator.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/android/android_helper.dart';
import 'package:PiliPlus/utils/device_utils.dart';
import 'package:PiliPlus/utils/extension/size_ext.dart';
import 'package:PiliPlus/utils/extension/string_ext.dart';
import 'package:PiliPlus/utils/feed_back.dart';
import 'package:PiliPlus/utils/global_data.dart';
import 'package:PiliPlus/utils/id_utils.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/request_utils.dart';
import 'package:PiliPlus/utils/share_utils.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class UgcIntroController extends CommonIntroController with ReloadMixin {
  late final RxBool expand;
  final RxBool status = true.obs;

  // up主粉丝数
  final Rx<MemberCardInfoData> userStat = MemberCardInfoData().obs;
  // 关注状态 默认未关注
  late final Rx<RelationData> followStatus = Rx(RelationData());
  late final RxMap staffRelations = {}.obs;

  // 是否点踩
  final RxBool hasDislike = false.obs;

  late final showArgueMsg = Pref.showArgueMsg;
  late final enableAi = Pref.enableAi;
  late final horizontalMemberPage = Pref.horizontalMemberPage;

  AiConclusionResult? aiConclusionResult;

  late final Map<int?, bool> seasonFavState = {};

  @override
  void onInit() {
    super.onInit();
    final alwaysExpandIntroPanel = Pref.alwaysExpandIntroPanel;
    expand = RxBool(alwaysExpandIntroPanel);
    if (!alwaysExpandIntroPanel && Pref.expandIntroPanelH) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!expand.value && !DeviceUtils.size.isPortrait) {
          expand.toggle();
        }
      });
    }
    videoDetail.value.title = Get.arguments['title'] ?? '';

    // 注册播控中心上一集/下一集回调
    videoPlayerServiceHandler?.onSkipToPrevious = () async => prevPlay();
    videoPlayerServiceHandler?.onSkipToNext = () async => nextPlay();
  }

  // 获取视频简介&分p
  @override
  Future<void> queryVideoIntro() async {
    queryVideoTags();
    final requestedBvid = bvid;
    final res = await VideoHttp.videoIntro(bvid: requestedBvid);
    if (isClosed || requestedBvid != bvid) return;
    if (res case Success(:final response)) {
      if (response.redirectUrl != null &&
          videoDetailCtr.epId == null &&
          videoDetailCtr.seasonId == null) {
        if (!isClosed) {
          PageUtils.viewPgcFromUri(response.redirectUrl!, off: true);
        }
        return;
      }
      videoPlayerServiceHandler?.onVideoDetailChange(
        response,
        cid.value,
        heroTag,
      );
      if (videoDetail.value.ugcSeason?.id == response.ugcSeason?.id) {
        // keep reversed season
        response.ugcSeason = videoDetail.value.ugcSeason;
      }
      if (videoDetail.value.cid == response.cid) {
        // keep reversed pages
        response
          ..pages = videoDetail.value.pages
          ..isPageReversed = videoDetail.value.isPageReversed;
      }
      videoDetail.value = response;
      try {
        if (videoDetailCtr.cover.value.isEmpty ||
            (videoDetailCtr.videoUrl.isNullOrEmpty &&
                !videoDetailCtr.isQuerying)) {
          videoDetailCtr.cover.value = response.pic ?? '';
        }
        if (videoDetailCtr.showReply) {
          try {
            Get.find<VideoReplyController>(tag: heroTag).count.value =
                response.stat?.reply ?? 0;
          } catch (_) {}
        }
      } catch (_) {}
      final pages = videoDetail.value.pages;
      if (pages != null && pages.isNotEmpty && cid.value == 0) {
        cid.value = pages.first.cid!;
      }
      queryUserStat(response.staff);
    } else {
      res.toast();
      status.value = false;
    }

    if (isLogin) {
      queryAllStatus();
      queryFollowStatus();
    }
  }

  // 获取up主粉丝数
  Future<void> queryUserStat(List<Staff>? staff) async {
    final requestedBvid = bvid;
    if (staff != null && staff.isNotEmpty) {
      final res = await Request().get(
        Api.relations,
        queryParameters: {'fids': staff.map((item) => item.mid).join(',')},
      );
      if (isClosed || requestedBvid != bvid) return;
      if (res.data['code'] == 0) {
        staffRelations.addAll({'status': true, ...?res.data['data']});
      }
    } else {
      final mid = videoDetail.value.owner?.mid;
      if (mid == null) {
        return;
      }
      final res = await MemberHttp.memberCardInfo(mid: mid);
      if (isClosed || requestedBvid != bvid) return;
      if (res case Success(:final response)) {
        userStat.value = response;
      }
    }
  }

  Future<void> queryAllStatus() async {
    final requestedBvid = bvid;
    final result = await VideoHttp.videoRelation(bvid: requestedBvid);
    if (isClosed || requestedBvid != bvid) return;
    if (result case Success(:final response)) {
      late final stat = videoDetail.value.stat;
      if (response.like!) {
        stat?.like = max(1, stat.like);
      }
      if (response.favorite!) {
        stat?.favorite = max(1, stat.favorite);
      }
      hasLike.value = response.like!;
      hasDislike.value = response.dislike!;
      coinNum.value = response.coin!;
      hasFav.value = response.favorite!;
    }
  }

  // 一键三连
  @override
  Future<void> actionTriple() async {
    feedBack();
    if (!isLogin) {
      SmartDialog.showToast('账号未登录');
      return;
    }
    if (hasLike.value && hasCoin && hasFav.value) {
      // 已点赞、投币、收藏
      SmartDialog.showToast('已三连');
      return;
    }
    final requestedBvid = bvid;
    final result = await VideoHttp.ugcTriple(bvid: requestedBvid);
    if (isClosed || requestedBvid != bvid) return;
    if (result case Success(:final response)) {
      late final stat = videoDetail.value.stat;
      if (response.like == true && !hasLike.value) {
        stat?.like++;
        hasLike.value = true;
      }
      if (response.coin == true && !hasCoin) {
        stat?.coin += 2;
        coinNum.value = 2;
        GlobalData().afterCoin(2);
      }
      if (response.fav == true && !hasFav.value) {
        stat?.favorite++;
        hasFav.value = true;
      }
      hasDislike.value = false;
      if (!hasCoin) {
        SmartDialog.showToast('投币失败');
      } else {
        SmartDialog.showToast('三连成功');
      }
    } else {
      result.toast();
    }
  }

  // （取消）点赞
  @override
  Future<void> actionLikeVideo() async {
    if (!isLogin) {
      SmartDialog.showToast('账号未登录');
      return;
    }
    if (videoDetail.value.stat == null) {
      return;
    }
    final requestedBvid = bvid;
    final newVal = !hasLike.value;
    final result = await VideoHttp.likeVideo(bvid: requestedBvid, type: newVal);
    if (isClosed || requestedBvid != bvid) return;
    if (result case Success(:final response)) {
      SmartDialog.showToast(newVal ? response : '取消赞');
      videoDetail.value.stat?.like += newVal ? 1 : -1;
      hasLike.value = newVal;
      if (newVal) {
        hasDislike.value = false;
      }
    } else {
      result.toast();
    }
  }

  Future<void> actionDislikeVideo() async {
    if (!isLogin) {
      SmartDialog.showToast('账号未登录');
      return;
    }
    final res = await VideoHttp.dislikeVideo(
      bvid: bvid,
      type: !hasDislike.value,
    );
    if (res.isSuccess) {
      if (!hasDislike.value) {
        SmartDialog.showToast('点踩成功');
        hasDislike.value = true;
        if (hasLike.value) {
          videoDetail.value.stat?.like--;
          hasLike.value = false;
        }
      } else {
        SmartDialog.showToast('取消踩');
        hasDislike.value = false;
      }
    } else {
      res.toast();
    }
  }

  @override
  int get copyright => videoDetail.value.copyright ?? 1;

  @override
  (Object, int) get getFavRidType => (IdUtils.bv2av(bvid), 2);

  @override
  StatDetail? getStat() => videoDetail.value.stat;

  // 分享视频
  @override
  void actionShareVideo(BuildContext context) {
    final videoDetail = this.videoDetail.value;
    final cid = this.cid.value;
    final partIndex = videoDetail.pages?.indexWhere((e) => e.cid == cid);
    final addIndex = partIndex != null && partIndex > 0;
    final playedTimePos = videoDetailCtr.playedTimePos(addIndex);
    final videoUrl =
        '${HttpString.baseUrl}/video/$bvid/${addIndex ? '?p=${partIndex + 1}' : ''}';
    showDialog(
      context: context,
      builder: (_) => SimpleDialog(
        clipBehavior: Clip.hardEdge,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          ListTile(
            dense: true,
            title: const Text(
              '复制链接',
              style: TextStyle(fontSize: 14),
            ),
            onTap: () {
              Get.back();
              Utils.copyText(videoUrl);
            },
            trailing: playedTimePos.isNotEmpty
                ? iconButton(
                    tooltip: '精确分享',
                    icon: const Icon(Icons.timer_outlined),
                    onPressed: () {
                      Get.back();
                      Utils.copyText('$videoUrl$playedTimePos');
                    },
                  )
                : null,
          ),
          ListTile(
            dense: true,
            title: const Text(
              '其它app打开',
              style: TextStyle(fontSize: 14),
            ),
            onTap: () {
              Get.back();
              PiliAndroidHelper.openUrl(videoUrl);
            },
          ),
          if (PlatformUtils.isMobile)
            ListTile(
              dense: true,
              title: const Text(
                '分享视频',
                style: TextStyle(fontSize: 14),
              ),
              onTap: () {
                Get.back();
                ShareUtils.shareText(
                  '${videoDetail.title} '
                  'UP主: ${videoDetail.owner!.name!}'
                  ' - $videoUrl',
                );
              },
            ),
          if (isLogin)
            ListTile(
              dense: true,
              title: const Text(
                '分享至动态',
                style: TextStyle(fontSize: 14),
              ),
              onTap: () {
                Get.back();
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (context) => RepostPanel(
                    rid: videoDetail.aid,
                    dynType: 8,
                    pic: videoDetail.pic,
                    title: videoDetail.title,
                    uname: videoDetail.owner?.name,
                  ),
                );
              },
            ),
          if (isLogin)
            ListTile(
              dense: true,
              title: const Text(
                '分享至消息',
                style: TextStyle(fontSize: 14),
              ),
              onTap: () {
                Get.back();
                try {
                  PageUtils.pmShare(
                    context,
                    content: {
                      "id": videoDetail.aid!.toString(),
                      "title": videoDetail.title!,
                      "headline": videoDetail.title!,
                      "source": 5,
                      "thumb": videoDetail.pic!,
                      "author": videoDetail.owner!.name!,
                      "author_id": videoDetail.owner!.mid!.toString(),
                    },
                  );
                } catch (e) {
                  SmartDialog.showToast(e.toString());
                }
              },
            ),
        ],
      ),
    );
  }

  // 查询关注状态
  Future<void> queryFollowStatus() async {
    final videoDetail = this.videoDetail.value;
    if (videoDetail.owner == null || videoDetail.staff?.isNotEmpty == true) {
      return;
    }
    final requestedBvid = bvid;
    final res = await UserHttp.userRelation(videoDetail.owner!.mid!);
    if (isClosed || requestedBvid != bvid) return;
    if (res case Success(:final response)) {
      if (response.special == 1) response.attribute = -10;
      followStatus.value = response;
    }
  }

  // 关注/取关up
  Future<void> actionRelationMod(BuildContext context) async {
    final requestedBvid = bvid;
    if (!isLogin) {
      SmartDialog.showToast('账号未登录');
      return;
    }
    final videoDetail = this.videoDetail.value;
    if (videoDetail.staff?.isNotEmpty == true) {
      return;
    }
    int? mid = videoDetail.owner?.mid;
    if (mid == null) {
      return;
    }
    int attr = followStatus.value.attribute ?? 0;
    if (attr == 128) {
      final res = await VideoHttp.relationMod(
        mid: mid,
        act: 6,
        reSrc: 11,
      );
      if (res.isSuccess) {
        followStatus
          ..value.attribute = 0
          ..refresh();
      }
      return;
    } else {
      RequestUtils.actionRelationMod(
        context: context,
        mid: mid,
        isFollow: attr != 0,
        followStatus: followStatus.value,
        afterMod: (attribute) {
          if (isClosed || requestedBvid != bvid) return;
          followStatus
            ..value.attribute = attribute
            ..refresh();
          Timer(const Duration(milliseconds: 500), queryFollowStatus);
        },
      );
    }
  }

  // 修改分P或番剧分集
  Future<bool> onChangeEpisode(
    BaseEpisodeItem episode, {
    bool isStein = false,
    bool waitForPlayback = false,
  }) async {
    try {
      final String bvid = episode.bvid ?? this.bvid;
      final int aid = episode.aid ?? IdUtils.bv2av(bvid);
      int? cid = episode.cid;
      Dimension? dimension;
      if (cid == null) {
        if (await SearchHttp.ab2cWithDimension(aid: aid, bvid: bvid)
            case final res?) {
          cid = res.cid;
          dimension = res.dimension;
        }
      }
      if (isClosed || cid == null) {
        return false;
      }

      final String? cover = episode.cover;

      // 重新获取视频资源
      if (videoDetailCtr.isPlayAll) {
        if (videoDetailCtr.mediaList.indexWhere((item) => item.bvid == bvid) ==
            -1) {
          if (dimension == null && episode is EpisodeItem) {
            dimension = episode.page?.dimension;
          }
          PageUtils.toVideoPage(
            bvid: bvid,
            cid: cid,
            cover: cover,
            dimension: dimension,
            title: episode.title,
          );
          return false;
        }
      }

      if (this.cid.value != cid || this.bvid != bvid) aiConclusionResult = null;

      videoDetailCtr
        ..plPlayerController.pause()
        ..makeHeartBeat()
        ..updateMediaListHistory(aid)
        ..onReset(isStein: isStein)
        ..bvid = bvid
        ..aid = aid
        ..cid.value = cid;
      final playback = videoDetailCtr.queryVideoUrl();

      if (this.bvid != bvid) {
        reload = true;
        aiConclusionResult = null;
        hasLike.value = false;
        hasDislike.value = false;
        coinNum.value = 0;
        hasFav.value = false;
        favIds = null;
        total.value = '1';
        userStat.value = MemberCardInfoData();
        followStatus.value = RelationData();

        if (cover != null && cover.isNotEmpty) {
          videoDetailCtr.cover.value = cover;
        }

        // 重新请求相关视频
        if (videoDetailCtr.plPlayerController.showRelatedVideo) {
          try {
            Get.find<RelatedController>(tag: heroTag)
              ..invalidateRequests()
              ..bvid = bvid
              ..queryData();
          } catch (_) {}
        }

        // 重新请求评论
        if (videoDetailCtr.showReply) {
          try {
            Get.find<VideoReplyController>(tag: heroTag).changeVideo(aid);
          } catch (_) {}
        }

        hasLater.value = videoDetailCtr.sourceType == SourceType.watchLater;
        this.bvid = bvid;
        queryVideoIntro();
      } else {
        if (episode is Part) {
          final videoDetail = this.videoDetail.value;
          videoPlayerServiceHandler?.onVideoDetailChange(
            episode,
            cid,
            heroTag,
            artist: videoDetail.owner?.name,
            cover: videoDetail.pic,
          );
        }
      }

      this.cid.value = cid;
      queryOnlineTotal();
      if (waitForPlayback) {
        try {
          await playback;
        } catch (_) {
          if (!isClosed && this.bvid == bvid) {
            videoDetailCtr.autoPlay = false;
            videoDetailCtr.videoState.value = false;
            SmartDialog.showToast('视频暂时无法播放，可点按重试或上滑切换');
          }
        }
      }
      return !isClosed;
    } catch (e) {
      if (kDebugMode) debugPrint('ugc onChangeEpisode: $e');
      return false;
    }
  }

  /// 播放上一个
  @override
  bool prevPlay([bool skipPart = false]) {
    final List<BaseEpisodeItem> episodes = <BaseEpisodeItem>[];
    bool isPart = false;

    final videoDetail = this.videoDetail.value;

    if (!skipPart && (videoDetail.pages?.length ?? 0) > 1) {
      isPart = true;
      episodes.addAll(videoDetail.pages!);
    } else if (videoDetailCtr.isPlayAll) {
      episodes.addAll(videoDetailCtr.mediaList);
    } else if (videoDetail.ugcSeason != null) {
      final UgcSeason ugcSeason = videoDetail.ugcSeason!;
      final List<SectionItem> sections = ugcSeason.sections!;
      for (int i = 0; i < sections.length; i++) {
        final List<EpisodeItem> episodesList = sections[i].episodes!;
        episodes.addAll(episodesList);
      }
    }

    final int currentIndex = episodes.indexWhere(
      (e) =>
          e.cid ==
          (skipPart
              ? videoDetail.isPageReversed
                    ? videoDetail.pages!.last.cid
                    : videoDetail.pages!.first.cid
              : this.cid.value),
    );

    int prevIndex = currentIndex - 1;
    final PlayRepeat playRepeat = videoDetailCtr.plPlayerController.playRepeat;

    // 列表循环
    if (prevIndex < 0) {
      if (isPart &&
          (videoDetailCtr.isPlayAll || videoDetail.ugcSeason != null)) {
        return prevPlay(true);
      }
      if (playRepeat == PlayRepeat.listCycle) {
        prevIndex = episodes.length - 1;
      } else {
        return false;
      }
    }

    int? cid = episodes[prevIndex].cid;
    while (cid == null) {
      prevIndex--;
      if (prevIndex < 0) {
        return false;
      }
      cid = episodes[prevIndex].cid;
    }

    if (cid != this.cid.value) {
      onChangeEpisode(episodes[prevIndex]);
      return true;
    } else {
      return false;
    }
  }

  /// 列表循环或者顺序播放时，自动播放下一个
  @override
  bool nextPlay([bool skipPart = false]) {
    try {
      final List<BaseEpisodeItem> episodes = <BaseEpisodeItem>[];
      bool isPart = false;
      final videoDetail = this.videoDetail.value;

      // part -> playall -> season
      if (!skipPart && (videoDetail.pages?.length ?? 0) > 1) {
        isPart = true;
        final List<Part> pages = videoDetail.pages!;
        episodes.addAll(pages);
      } else if (videoDetailCtr.isPlayAll) {
        episodes.addAll(videoDetailCtr.mediaList);
      } else if (videoDetail.ugcSeason != null) {
        final UgcSeason ugcSeason = videoDetail.ugcSeason!;
        final List<SectionItem> sections = ugcSeason.sections!;
        for (int i = 0; i < sections.length; i++) {
          final List<EpisodeItem> episodesList = sections[i].episodes!;
          episodes.addAll(episodesList);
        }
      }

      final PlayRepeat playRepeat =
          videoDetailCtr.plPlayerController.playRepeat;

      if (episodes.isEmpty) {
        if (playRepeat == PlayRepeat.listCycle) {
          videoDetailCtr.plPlayerController.play(repeat: true);
          return true;
        }
        if (playRepeat == PlayRepeat.autoPlayRelated &&
            videoDetailCtr.plPlayerController.showRelatedVideo) {
          return playRelated();
        }
        return false;
      }

      final int currentIndex = episodes.indexWhere(
        (e) =>
            e.cid ==
            (skipPart
                ? videoDetail.isPageReversed
                      ? videoDetail.pages!.last.cid
                      : videoDetail.pages!.first.cid
                : this.cid.value),
      );

      int nextIndex = currentIndex + 1;

      if (!isPart &&
          videoDetailCtr.isPlayAll &&
          currentIndex == episodes.length - 2) {
        videoDetailCtr.getMediaList();
      }

      // 列表循环
      if (nextIndex >= episodes.length) {
        if (isPart &&
            (videoDetailCtr.isPlayAll || videoDetail.ugcSeason != null)) {
          return nextPlay(true);
        }

        if (playRepeat == PlayRepeat.listCycle) {
          nextIndex = 0;
        } else if (playRepeat == PlayRepeat.autoPlayRelated &&
            videoDetailCtr.plPlayerController.showRelatedVideo) {
          return playRelated();
        } else {
          return false;
        }
      }

      int? cid = episodes[nextIndex].cid;
      while (cid == null) {
        nextIndex++;
        if (nextIndex >= episodes.length) {
          return false;
        }
        cid = episodes[nextIndex].cid;
      }

      if (cid != this.cid.value) {
        onChangeEpisode(episodes[nextIndex]);
        return true;
      } else {
        return false;
      }
    } catch (_) {
      return false;
    }
  }

  bool playRelated() {
    RelatedController relatedCtr;
    if (Get.isRegistered<RelatedController>(tag: heroTag)) {
      relatedCtr = Get.find<RelatedController>(tag: heroTag);
    } else {
      relatedCtr = Get.put(RelatedController(autoQuery: false), tag: heroTag)
        ..queryData().whenComplete(playRelated);
      return false;
    }

    if (relatedCtr.loadingState.value case Success(:final response)) {
      final firstItem = response?.firstOrNull;
      if (firstItem == null) {
        SmartDialog.showToast('暂无相关视频，停止连播');
        return false;
      }
      onChangeEpisode(
        BaseEpisodeItem(
          aid: firstItem.aid,
          bvid: firstItem.bvid,
          cid: firstItem.cid,
          cover: firstItem.cover,
        ),
      );
      return true;
    }

    return false;
  }

  // One request at a time also prevents stacked loading dialogs on rapid taps.
  static bool _aiLoading = false;
  static Future<AiConclusionResult?> getAiConclusion(
    String bvid,
    int cid,
    int? mid, {
    bool Function()? isCurrent,
  }) async {
    if (!Accounts.heartbeat.isLogin) {
      SmartDialog.showToast('用于播放记录的账号未登录，请检查账号设置');
      return null;
    }
    if (_aiLoading) return null;
    _aiLoading = true;
    final request = AiConclusionRequest();
    final route = Get.currentRoute;
    bool stillCurrent() =>
        Get.currentRoute == route && isCurrent?.call() != false;
    SmartDialog.showLoading(
      msg: '正在获取 AI 总结，返回可取消',
      backType: SmartBackType.normal,
      onDismiss: request.cancel,
    );
    String? message;
    try {
      final res = await request.run(
        () => VideoHttp.aiConclusion(bvid: bvid, cid: cid, upMid: mid),
        isCurrent: stillCurrent,
      );
      if (res case Success(:final response)) {
        if (response.hasContent) return response.modelResult;
        message = response.unavailableMessage;
      } else if (res case Error(:final code, :final errMsg)) {
        message = switch (code) {
          -101 => '登录状态已失效，请重新登录后获取 AI 总结',
          -412 || -352 => '哔哩哔哩暂时限制了此请求，请稍后重试',
          _ =>
            errMsg?.isNotEmpty == true
                ? '获取 AI 总结失败：$errMsg'
                : '获取 AI 总结失败${code == null ? '' : '（$code）'}',
        };
      }
    } catch (_) {
      if (!request.isCancelled && stillCurrent()) {
        message = '获取 AI 总结失败，请检查网络后重试';
      }
    } finally {
      if (!request.isCancelled) {
        await SmartDialog.dismiss(status: SmartStatus.loading);
      }
      _aiLoading = false;
      if (message != null && stillCurrent()) SmartDialog.showToast(message);
    }
    return null;
  }

  Future<void> aiConclusion() async {
    final requestedBvid = bvid;
    final requestedCid = cid.value;
    final result = await getAiConclusion(
      requestedBvid,
      requestedCid,
      videoDetail.value.owner?.mid,
      isCurrent: () =>
          !isClosed && bvid == requestedBvid && cid.value == requestedCid,
    );
    if (!isClosed && bvid == requestedBvid && cid.value == requestedCid)
      aiConclusionResult = result;
  }
}
