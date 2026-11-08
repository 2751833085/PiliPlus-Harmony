import 'dart:convert';
import 'dart:typed_data';

import 'package:PiliPlus/models/common/dynamic/dynamic_badge_mode.dart';
import 'package:PiliPlus/models/common/dynamic/dynamics_type.dart';
import 'package:PiliPlus/models/common/home_tab_type.dart';
import 'package:PiliPlus/models/common/msg/msg_unread_type.dart';
import 'package:PiliPlus/models/common/nav_bar_config.dart';
import 'package:PiliPlus/models/common/theme/theme_type.dart';
import 'package:PiliPlus/models/common/video/video_decode_type.dart';
import 'package:PiliPlus/models/model_owner.dart';
import 'package:PiliPlus/models/user/danmaku_rule.dart';
import 'package:PiliPlus/models/user/danmaku_rule_adapter.dart';
import 'package:PiliPlus/models/user/info.dart';
import 'package:PiliPlus/plugin/pl_player/models/fullscreen_mode.dart';
import 'package:PiliPlus/plugin/pl_player/models/play_repeat.dart';
import 'package:PiliPlus/plugin/pl_player/models/video_fit_type.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/accounts/account_adapter.dart';
import 'package:PiliPlus/utils/accounts/account_type_adapter.dart';
import 'package:PiliPlus/utils/accounts/cookie_jar_adapter.dart';
import 'package:PiliPlus/utils/device_utils.dart';
import 'package:PiliPlus/utils/font_utils.dart';
import 'package:PiliPlus/utils/path_utils.dart';
import 'package:PiliPlus/utils/set_int_adapter.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:flex_seed_scheme/flex_seed_scheme.dart' show FlexSchemeVariant;
import 'package:hive_ce/hive.dart';
import 'package:path/path.dart' as path;

abstract final class GStorage {
  static late final Box<UserInfoData> userInfo;
  static late final Box<dynamic> historyWord;
  static late final Box<dynamic> localCache;
  static late final Box<dynamic> setting;
  static late final Box<dynamic> video;
  static late final Box<int> watchProgress;
  static late final Box<Uint8List>? reply;

  static Future<void> init() async {
    Hive.init(path.join(appSupportDirPath, 'hive'));
    regAdapter();

    await Future.wait([
      // 登录用户信息
      Hive.openBox<UserInfoData>(
        'userInfo',
        compactionStrategy: (int entries, int deletedEntries) {
          return deletedEntries > 2;
        },
      ).then((res) => userInfo = res),
      // 本地缓存
      Hive.openBox(
        'localCache',
        compactionStrategy: (int entries, int deletedEntries) {
          return deletedEntries > 4;
        },
      ).then((res) => localCache = res),
      // 设置
      Hive.openBox('setting').then((res) => setting = res),
      // 搜索历史
      Hive.openBox(
        'historyWord',
        compactionStrategy: (int entries, int deletedEntries) {
          return deletedEntries > 10;
        },
      ).then((res) => historyWord = res),
      // 视频设置
      Hive.openBox('video').then((res) => video = res),
      Accounts.init(),
      Hive.openBox<int>(
        'watchProgress',
        keyComparator: _intStrDescKeyComparator,
        compactionStrategy: (entries, deletedEntries) {
          return deletedEntries > 4;
        },
      ).then((res) => watchProgress = res),
    ]);

    _migrateFullScreenMode();

    if (Pref.saveReply) {
      reply = await Hive.openBox<Uint8List>(
        'reply',
        keyComparator: _intStrDescKeyComparator,
        compactionStrategy: (entries, deletedEntries) {
          return deletedEntries > 10;
        },
      );
    } else {
      reply = null;
    }
  }

  /// 一次性迁移：旧版本的 Pref.fullScreenMode 会把按「平板 + 横屏适配」推导出的
  /// 默认值落库，平板上即「不改变当前方向」。它一旦被冻结，之后无论开关怎么调，
  /// 点全屏按钮都不会按视频方向转屏。这里把平板上的该值清掉，让它回到新的默认值
  /// 「按视频方向」；手机上的「不改变当前方向」只可能是用户显式选的，不动。
  static void _migrateFullScreenMode() {
    if (setting.get(SettingBoxKey.fullScreenModeMigrated) == true) return;
    setting.put(SettingBoxKey.fullScreenModeMigrated, true);
    if (DeviceUtils.isTablet &&
        setting.get(SettingBoxKey.fullScreenMode) ==
            FullScreenMode.none.index) {
      setting.delete(SettingBoxKey.fullScreenMode);
    }
  }

  static const _danmakuRulesKey = 'danmakuRules';
  static bool _restoringSettings = false;

  static String exportAllSettings() {
    final RuleFilter? rules = localCache.get(LocalCacheKey.danmakuFilterRules);
    return Utils.jsonEncoder.convert({
      setting.name: setting.toMap(),
      video.name: video.toMap(),
      _danmakuRulesKey: rules == null
          ? null
          : {
              'keywords': rules.dmFilterString,
              'patterns': rules.dmRegExp.map((rule) => rule.pattern).toList(),
              'userHashes': rules.dmUid.toList(),
            },
    });
  }

  static Future<void> importAllSettings(String data) async {
    final json = jsonDecode(data);
    await importAllJsonSettings(_backupMap(json, '设置备份'));
  }

  static Future<void> importAllJsonSettings(Map<String, dynamic> map) async {
    if (_restoringSettings) throw StateError('正在恢复设置');
    final settings = _backupMap(map[setting.name], '应用设置')
      ..removeWhere((_, value) => value == null);
    final player = _backupMap(map[video.name], '播放器设置')
      ..removeWhere((_, value) => value == null);
    final restoreRules = map.containsKey(_danmakuRulesKey);
    final rules = _backupRules(map[_danmakuRulesKey]);
    final previousSettings = setting.toMap();
    final previousPlayer = video.toMap();
    _validateStoredTypes(settings, previousSettings);
    _validateStoredTypes(player, previousPlayer);
    _validateSettings(settings, player);

    // Backups carry font preferences, while the font file is device-local.
    final font = settings[SettingBoxKey.appFont] as String?;
    if (font != null &&
        font.contains('/') &&
        (setting.get(SettingBoxKey.appFont) != font ||
            !FontUtils.fontFile.existsSync())) {
      settings.remove(SettingBoxKey.appFont);
    }

    final RuleFilter? previousRules = restoreRules
        ? localCache.get(LocalCacheKey.danmakuFilterRules)
        : null;
    _restoringSettings = true;
    try {
      await _replaceBox(setting, settings);
      await _replaceBox(video, player);
      if (restoreRules) await _writeBackupRules(rules);
    } catch (_) {
      try {
        await Future.wait([
          _replaceBox(setting, previousSettings),
          _replaceBox(video, previousPlayer),
          if (restoreRules) _writeBackupRules(previousRules),
        ]);
      } catch (_) {
        throw StateError('设置写入失败，旧设置未能完全恢复');
      }
      rethrow;
    } finally {
      _restoringSettings = false;
    }
  }

  static Future<void> _writeBackupRules(RuleFilter? rules) => rules == null
      ? localCache.delete(LocalCacheKey.danmakuFilterRules)
      : localCache.put(LocalCacheKey.danmakuFilterRules, rules);

  static Future<void> _replaceBox(
    Box box,
    Map<dynamic, dynamic> entries,
  ) async {
    final removedKeys = box.keys
        .where((key) => !entries.containsKey(key))
        .toList();
    await box.putAll(entries);
    await box.deleteAll(removedKeys);
  }

  static Map<String, dynamic> _backupMap(Object? value, String label) {
    if (value is! Map || value.keys.any((key) => key is! String)) {
      throw FormatException('$label格式无效');
    }
    return Map<String, dynamic>.from(value);
  }

  static RuleFilter? _backupRules(Object? value) {
    if (value == null) return null;
    final rules = _backupMap(value, '弹幕屏蔽规则');
    List<String> strings(String key) {
      final values = rules[key];
      if (values is! List || values.any((item) => item is! String)) {
        throw const FormatException('弹幕屏蔽规则格式无效');
      }
      return List<String>.from(values);
    }

    return RuleFilter(
      strings('keywords'),
      strings(
        'patterns',
      ).map((rule) => RegExp(rule, caseSensitive: false)).toList(),
      strings('userHashes').toSet(),
    );
  }

  static void _validateStoredTypes(
    Map<String, dynamic> incoming,
    Map<dynamic, dynamic> previous,
  ) {
    for (final key in incoming.keys.toList()) {
      final value = incoming[key];
      final valid = switch (previous[key]) {
        bool() => value is bool,
        int() => value is int,
        double() => value is num && value.isFinite,
        String() => value is String,
        List() || Set() => value is List,
        Map() => value is Map,
        _ => true,
      };
      if (!valid) throw FormatException('设置项 $key 格式无效');
      if (previous[key] is double && value is num) {
        incoming[key] = value.toDouble();
      }
    }
  }

  static void _validateSettings(
    Map<String, dynamic> settings,
    Map<String, dynamic> player,
  ) {
    void validate(
      Map<String, dynamic> values,
      String key,
      bool Function(Object? value) valid,
    ) {
      if (values.containsKey(key) && !valid(values[key])) {
        throw FormatException('设置项 $key 格式无效');
      }
    }

    bool enumIndex(Object? value, int count) =>
        value is int && value >= 0 && value < count;
    bool positiveNumber(Object? value) =>
        value is num && value.isFinite && value > 0;
    for (final (key, min, max) in [
      (SettingBoxKey.uiScale, 0.5, 2.0),
      (SettingBoxKey.defaultTextScale, 0.85, 1.6),
    ]) {
      validate(
        settings,
        key,
        (value) => value is num && value >= min && value <= max,
      );
      if (settings[key] case final num value) settings[key] = value.toDouble();
    }
    for (final key in [SettingBoxKey.appFontWeightV2, 'appFontWeight']) {
      validate(
        settings,
        key,
        (value) => value is int && value >= -1 && value < 9,
      );
    }
    for (final (key, count) in [
      (SettingBoxKey.navBarSort, NavigationBarType.values.length),
      (SettingBoxKey.tabBarSort, HomeTabType.values.length),
      (SettingBoxKey.msgUnReadTypeV2, MsgUnReadType.values.length),
    ]) {
      validate(
        settings,
        key,
        (value) =>
            value is List && value.every((index) => enumIndex(index, count)),
      );
    }
    for (final (key, count) in [
      (SettingBoxKey.dynamicBadgeMode, DynamicBadgeMode.values.length),
      (SettingBoxKey.msgBadgeMode, DynamicBadgeMode.values.length),
      (SettingBoxKey.schemeVariant, FlexSchemeVariant.values.length),
    ]) {
      validate(settings, key, (value) => enumIndex(value, count));
    }
    validate(
      settings,
      SettingBoxKey.themeMode,
      (value) => enumIndex(value, ThemeType.values.length),
    );
    validate(
      settings,
      SettingBoxKey.fullScreenMode,
      (value) =>
          value == null || enumIndex(value, FullScreenMode.values.length),
    );
    validate(
      settings,
      SettingBoxKey.appFont,
      (value) => value == null || value is String,
    );
    validate(
      settings,
      SettingBoxKey.feedColumns,
      (value) => value is List && value.every((item) => item is int),
    );
    for (final key in [
      SettingBoxKey.harmonyImmersive,
      SettingBoxKey.translucentBottomBar,
      SettingBoxKey.harmonyFoldOrientation,
      SettingBoxKey.tabletCombinedRightPanel,
      SettingBoxKey.dualFoldCommentsBelowVideo,
      SettingBoxKey.tabletVideoInfoOnRight,
      SettingBoxKey.showMineHistory,
      SettingBoxKey.overseasMode,
      SettingBoxKey.autoPlayEnable,
      SettingBoxKey.enableSlideFS,
      SettingBoxKey.enableSlideVolumeBrightness,
      SettingBoxKey.enableQuickDouble,
      SettingBoxKey.fullScreenGestureReverse,
      SettingBoxKey.useRelativeSlide,
      SettingBoxKey.enableHA,
      SettingBoxKey.enableBackgroundPlay,
      SettingBoxKey.continuePlayInBackground,
      SettingBoxKey.enableShowDanmaku,
      SettingBoxKey.mergeDanmaku,
      SettingBoxKey.showVipDanmaku,
      SettingBoxKey.enableSaveLastData,
      SettingBoxKey.recordSearchHistory,
      SettingBoxKey.searchSuggestion,
      SettingBoxKey.enableSystemProxy,
    ]) {
      validate(settings, key, (value) => value is bool);
    }
    validate(
      player,
      VideoBoxKey.playRepeat,
      (value) => enumIndex(value, PlayRepeat.values.length),
    );
    validate(
      player,
      VideoBoxKey.cacheVideoFit,
      (value) => enumIndex(value, VideoFitType.values.length),
    );
    validate(
      settings,
      SettingBoxKey.defaultHomePage,
      (value) => enumIndex(value, NavigationBarType.values.length),
    );
    validate(
      settings,
      SettingBoxKey.defaultDynamicType,
      (value) => enumIndex(value, DynamicsTabType.values.length),
    );
    validate(settings, SettingBoxKey.customColor, (value) => value is int);
    for (final key in [
      SettingBoxKey.preferCodecs,
      SettingBoxKey.preferCodecsCellular,
    ]) {
      validate(
        settings,
        key,
        (value) =>
            value is List &&
            value.every(
              (codec) => VideoDecodeFormatType.values.any(
                (format) => format.name == codec,
              ),
            ),
      );
    }
    validate(
      settings,
      SettingBoxKey.danmakuBlockType,
      (value) => value is List && value.every((item) => item is int),
    );
    for (final key in [
      VideoBoxKey.playSpeedDefault,
      VideoBoxKey.longPressSpeedDefault,
    ]) {
      validate(player, key, positiveNumber);
      if (player[key] case final num value) player[key] = value.toDouble();
    }
    validate(
      player,
      VideoBoxKey.speedsList,
      (value) => value is List && value.every(positiveNumber),
    );
    if (player[VideoBoxKey.speedsList] case final List values) {
      player[VideoBoxKey.speedsList] = [
        for (final num value in values) value.toDouble(),
      ];
    }
  }

  static void regAdapter() {
    Hive
      ..registerAdapter(OwnerAdapter())
      ..registerAdapter(UserInfoDataAdapter())
      ..registerAdapter(LevelInfoAdapter())
      ..registerAdapter(BiliCookieJarAdapter())
      ..registerAdapter(LoginAccountAdapter())
      ..registerAdapter(AccountTypeAdapter())
      ..registerAdapter(SetIntAdapter())
      ..registerAdapter(RuleFilterAdapter());
  }

  static Future<List<void>> compact() {
    return Future.wait([
      userInfo.compact(),
      historyWord.compact(),
      localCache.compact(),
      setting.compact(),
      video.compact(),
      Accounts.account.compact(),
      watchProgress.compact(),
      ?reply?.compact(),
    ]);
  }

  static Future<List<void>> close() {
    return Future.wait([
      userInfo.close(),
      historyWord.close(),
      localCache.close(),
      setting.close(),
      video.close(),
      Accounts.account.close(),
      watchProgress.close(),
      ?reply?.close(),
    ]);
  }

  static Future<List<void>> clear() {
    return Future.wait([
      userInfo.clear(),
      historyWord.clear(),
      localCache.clear(),
      setting.clear(),
      video.clear(),
      Accounts.clear(),
      watchProgress.clear(),
      ?reply?.clear(),
    ]);
  }

  static int _intStrDescKeyComparator(dynamic k1, dynamic k2) {
    if (k1 is int) {
      if (k2 is int) {
        return k2.compareTo(k1);
      } else {
        return -1;
      }
    } else if (k2 is String) {
      final lenCompare = k2.length.compareTo((k1 as String).length);
      if (lenCompare == 0) {
        return k2.compareTo(k1);
      } else {
        return lenCompare;
      }
    } else {
      return 1;
    }
  }
}
