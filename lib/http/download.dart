import 'package:dio/dio.dart' show CancelToken;
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models/common/account_type.dart';
import 'package:PiliPlus/models/common/video/audio_quality.dart';
import 'package:PiliPlus/models/common/video/video_quality.dart';
import 'package:PiliPlus/models/common/video/video_type.dart';
import 'package:PiliPlus/models/video/play/url.dart';
import 'package:PiliPlus/models_new/download/bili_download_entry_info.dart';
import 'package:PiliPlus/models_new/download/bili_download_media_file_info.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/extension/iterable_ext.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/video_utils.dart';
import 'package:collection/collection.dart';

abstract final class DownloadHttp {
  static const String referer = "https://www.bilibili.com/";
  static const String userAgent = "Bilibili Freedoooooom/MarkII";

  static Future<BiliDownloadMediaInfo> getVideoUrl({
    required BiliDownloadEntryInfo entry,
    SourceInfo? source,
    PageInfo? pageData,
    EpInfo? ep,
    CancelToken? cancelToken,
  }) async {
    final isLogin = Accounts.get(AccountType.video).isLogin;
    final res = await VideoHttp.videoUrl(
      avid: entry.avid,
      bvid: entry.bvid,
      cid: entry.cid,
      cancelToken: cancelToken,
      seasonId: entry.seasonId,
      epid: ep?.episodeId,
      qn: entry.preferedVideoQuality,
      tryLook: !isLogin && Pref.p1080,
      videoType: switch (ep?.from) {
        'pugv' => VideoType.pugv,
        != null when isLogin => VideoType.pgc,
        _ => VideoType.ugc,
      },
    );
    if (cancelToken?.cancelError case final error?) throw error;
    if (res case Success(:final response)) {
      final dash = response.dash;
      if (dash != null) {
        final targetVideoQa = response.findAvailableVideoQuality(
          entry.preferedVideoQuality,
        );

        /// 优先顺序 设置中指定解码格式 -> 当前可选的首个解码格式
        final supportFormats = response.supportFormats!;
        // 根据画质选编码格式
        final targetSupportFormats = supportFormats.firstWhere(
          (e) => e.quality == targetVideoQa,
          orElse: () => supportFormats.first,
        );

        final currentDecodeFormats = VideoUtils.selectCodec(
          targetSupportFormats.codecs!,
          Pref.preferCodecs,
        );

        /// 取出符合当前画质的videoList
        final videosList = dash.video!
            .where((e) => e.quality.code == targetVideoQa)
            .toList();

        /// 取出符合当前解码格式的videoItem
        final videoDash = videosList.firstWhere(
          (e) => currentDecodeFormats.codes.any(e.codecs!.startsWith),
          orElse: () => videosList.first,
        );

        final videoUrl = VideoUtils.getCdnUrl(videoDash.playUrls);

        final Type2File videoFile = Type2File(
          id: videoDash.id,
          baseUrl: videoUrl,
          bandwidth: videoDash.bandWidth!,
          codecid: videoDash.codecid!,
          size: 0,
          md5: '',
          noRexcode: false,
          frameRate: videoDash.frameRate ?? '',
          width: videoDash.width!,
          height: videoDash.height!,
          dashDrmType: 0,
        );
        List<Type2File>? audioFileList;
        final List<AudioItem>? audioDashList = dash.audio;
        if (audioDashList != null && audioDashList.isNotEmpty) {
          final preferAudioQa = Pref.defaultAudioQa;
          final List<int> audioIds = audioDashList
              .map((map) => map.id)
              .toList();
          int closestNumber = audioIds.findClosestTarget(
            (e) => e <= preferAudioQa,
            (a, b) => a > b ? a : b,
          );
          if (!audioIds.contains(preferAudioQa) &&
              audioIds.any((e) => e > preferAudioQa)) {
            closestNumber = AudioQuality.k192.code;
          }
          final AudioItem audioDash = audioDashList.firstWhere(
            (e) => e.id == closestNumber,
            orElse: () => audioDashList.first,
          );
          final audioUrl = VideoUtils.getCdnUrl(
            audioDash.playUrls,
            isAudio: true,
          );
          audioFileList = [
            Type2File(
              id: audioDash.id,
              baseUrl: audioUrl,
              bandwidth: audioDash.bandWidth!,
              codecid: audioDash.codecid!,
              size: 0,
              md5: '',
              noRexcode: false,
              frameRate: audioDash.frameRate!,
              width: audioDash.width!,
              height: audioDash.height!,
              dashDrmType: 0,
            ),
          ];
        }
        final media = Type2(
          duration: dash.duration!,
          video: [videoFile],
          audio: audioFileList,
          referer: referer,
          userAgent: userAgent,
        );
        entry
          ..mediaType = 2
          ..hasDashAudio = audioFileList != null
          ..typeTag = targetVideoQa.toString()
          ..videoQuality = targetVideoQa
          ..preferedVideoQuality = targetVideoQa
          ..qualityPithyDescription =
              targetSupportFormats.newDesc ??
              VideoQuality.fromCode(targetVideoQa).desc;
        return media;
      } else {
        final segments = response.durl;
        if (segments == null || segments.isEmpty) {
          throw StateError('没有可用的离线视频资源');
        }
        if (segments.length > 1) {
          throw UnsupportedError('暂不支持分段视频的离线缓存');
        }
        final first = segments.single;
        final List<Type1Segment> segmentList = [
          Type1Segment(
            backupUrls: [],
            bytes: first.size!,
            duration: first.length!,
            md5: '',
            metaUrl: '',
            order: first.order!,
            url: VideoUtils.getCdnUrl(first.playUrls),
          ),
        ];
        final FormatItem? formatItem = response.supportFormats
            ?.firstWhereOrNull((e) => e.quality == response.quality);
        final String description =
            formatItem?.newDesc ?? VideoQuality.clear480.desc;
        final int targetVideoQa =
            formatItem?.quality ?? VideoQuality.clear480.code;

        final List<Type1PlayerCodecConfig> playerCodecConfigList = [
          Type1PlayerCodecConfig(
            player: "IJK_PLAYER",
            useIjkMediaCodec: false,
          ),
          Type1PlayerCodecConfig(
            player: "ANDROID_PLAYER",
            useIjkMediaCodec: false,
          ),
        ];

        final media = Type1(
          from: pageData?.from ?? ep?.from,
          quality: targetVideoQa,
          typeTag: targetVideoQa.toString(),
          description: description,
          playerCodecConfigList: playerCodecConfigList,
          segmentList: segmentList,
          parseTimestampMilli: 0,
          availablePeriodMilli: 0,
          isDownloaded: false,
          isResolved: true,
          timeLength: 0,
          marlinToken: '',
          videoCodecId: 0,
          videoProject: true,
          format: response.format!,
          playerError: 0,
          needVip: false,
          needLogin: false,
          intact: false,
          referer: referer,
          userAgent: userAgent,
        );
        entry
          ..mediaType = 1
          ..hasDashAudio = false
          ..typeTag = targetVideoQa.toString()
          ..videoQuality = targetVideoQa
          ..preferedVideoQuality = targetVideoQa
          ..qualityPithyDescription = description;
        return media;
      }
    } else {
      throw res.toString();
    }
  }
}
