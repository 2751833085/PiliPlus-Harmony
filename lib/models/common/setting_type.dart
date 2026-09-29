import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/pages/setting/models/experimental_settings.dart';
import 'package:PiliPlus/pages/setting/models/extra_settings.dart';
import 'package:PiliPlus/pages/setting/models/model.dart';
import 'package:PiliPlus/pages/setting/models/play_settings.dart';
import 'package:PiliPlus/pages/setting/models/privacy_settings.dart';
import 'package:PiliPlus/pages/setting/models/recommend_settings.dart';
import 'package:PiliPlus/pages/setting/models/style_settings.dart';
import 'package:PiliPlus/pages/setting/models/video_settings.dart';

enum SettingType {
  privacySetting('隐私设置'),
  recommendSetting('个性化设置'),
  videoSetting('音视频设置'),
  playSetting('播放器设置'),
  styleSetting('外观设置'),
  extraSetting('其他设置'),
  experimentalSetting('鸿蒙特色功能'),
  webdavSetting('WebDAV 设置'),
  about('关于'),
  featuredSetting('特色功能'),
  ;

  static const searchable = [
    styleSetting,
    playSetting,
    videoSetting,
    recommendSetting,
    privacySetting,
    extraSetting,
  ];

  /// Shared rows may have multiple relevant homes, but search shows one result.
  static List<SettingsModel> get searchSettings => [
    ...{
      for (final type in searchable)
        for (final row in type.settings) row.searchIdentity: row,
    }.values,
  ];

  static const _featuredIdentities = {
    'setting:${SettingBoxKey.enableSponsorBlock}',
    'setting:${SettingBoxKey.overseasMode}',
    'setting:${SettingBoxKey.shortVideoMode}',
    'title:竖屏左滑动作',
    'title:竖屏右滑动作',
    'setting:${SettingBoxKey.shortPreload}',
    'setting:${SettingBoxKey.enableAi}',
    'setting:${SettingBoxKey.biliPlayerControls}',
    'setting:${SettingBoxKey.harmonyHandedness}',
    'setting:${SettingBoxKey.harmonyFoldOrientation}',
    'setting:${SettingBoxKey.harmonyImmersive}',
    'title:应用接续',
    'title:后台下载离线缓存视频',
  };

  static List<SettingsModel> get _featuredSettings {
    final rows = {for (final row in searchSettings) row.searchIdentity: row};
    return [
      for (final identity in _featuredIdentities)
        if (rows.containsKey(identity)) rows[identity]!,
    ];
  }

  final String title;
  const SettingType(this.title);

  List<SettingsModel> get settings => switch (this) {
    .featuredSetting => _featuredSettings,
    .privacySetting => privacySettings,
    .recommendSetting => prioritizeSettings(
      [...recommendSettings, ...personalizationExtraSettings],
      sections: const ['推荐偏好', '内容过滤', '搜索偏好', '评论偏好', '动态偏好', '消息偏好', '评论与隐私'],
    ),
    .videoSetting => videoSettings,
    .playSetting => playSettings,
    .styleSetting => styleSettings,
    .extraSetting => extraSettings,
    .experimentalSetting => experimentalSettings,
    _ => throw UnimplementedError(),
  };
}
