import 'dart:convert';
import 'dart:io';

import 'package:PiliPlus/models/user/danmaku_rule.dart';
import 'package:PiliPlus/utils/path_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

class _FailingBox implements Box<dynamic> {
  _FailingBox(this.box);

  final Box<dynamic> box;
  bool failNextWrite = false;

  void _maybeFail() {
    if (!failNextWrite) return;
    failNextWrite = false;
    throw const FileSystemException('fixture failure after write');
  }

  @override
  String get name => box.name;
  @override
  Iterable<dynamic> get keys => box.keys;
  @override
  Map<dynamic, dynamic> toMap() => box.toMap();
  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      box.get(key, defaultValue: defaultValue);
  @override
  Future<int> clear() => box.clear();
  @override
  Future<void> delete(dynamic key) => box.delete(key);
  @override
  Future<void> deleteAll(Iterable<dynamic> keys) => box.deleteAll(keys);
  @override
  Future<void> put(dynamic key, dynamic value) async {
    await box.put(key, value);
    _maybeFail();
  }

  @override
  Future<void> putAll(Map<dynamic, dynamic> entries) async {
    await box.putAll(entries);
    _maybeFail();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory sandbox;
  late _FailingBox playerBox;
  late _FailingBox cacheBox;
  const ruleKey = LocalCacheKey.danmakuFilterRules;

  setUpAll(() async {
    sandbox = await Directory.systemTemp.createTemp('pili-settings-backup-');
    appSupportDirPath = sandbox.path;
    Hive.init(sandbox.path);
    GStorage.regAdapter();
    GStorage.setting = await Hive.openBox('setting');
    GStorage.video = playerBox = _FailingBox(await Hive.openBox('video'));
    GStorage.localCache = cacheBox = _FailingBox(
      await Hive.openBox('localCache'),
    );
  });
  setUp(() async {
    await GStorage.setting.clear();
    await GStorage.video.clear();
    await GStorage.localCache.clear();
  });
  tearDownAll(() async {
    await Hive.close();
    await sandbox.delete(recursive: true);
  });

  test(
    'settings and local danmaku rules round trip without cache or media',
    () async {
      final settings = {
        SettingBoxKey.harmonyImmersive: false,
        SettingBoxKey.translucentBottomBar: true,
        SettingBoxKey.tabletCombinedRightPanel: false,
        SettingBoxKey.harmonyRefreshSensitivity: 'light',
        SettingBoxKey.feedColumns: [1, 2, 3, 4, 0, 0],
        SettingBoxKey.overseasMode: true,
        SettingBoxKey.danmakuBlockType: [2, 4, 7],
        SettingBoxKey.danmakuOpacity: 0.8,
        'legacyPreference': 'retained',
      };
      final player = {
        VideoBoxKey.playSpeedDefault: 1.5,
        VideoBoxKey.speedsList: [0.5, 1.0, 2.0],
      };
      await GStorage.setting.putAll(settings);
      await GStorage.video.putAll(player);
      await GStorage.localCache.put(
        ruleKey,
        RuleFilter(
          ['muted phrase'],
          [RegExp(r'^blocked\d+$', caseSensitive: false)],
          {'1234abc'},
        ),
      );
      await GStorage.localCache.put(
        LocalCacheKey.mixinKey,
        'fixture-cache-only',
      );
      final backup = GStorage.exportAllSettings();
      final json = jsonDecode(backup) as Map<String, dynamic>;
      expect(json.keys, unorderedEquals(['setting', 'video', 'danmakuRules']));
      expect(backup, isNot(contains('fixture-cache-only')));
      await GStorage.setting.put('obsoleteOnTarget', true);
      await GStorage.video.clear();
      await GStorage.localCache.delete(ruleKey);
      await GStorage.localCache.put(
        LocalCacheKey.mixinKey,
        'target-cache-only',
      );
      await GStorage.importAllSettings(backup);

      expect(GStorage.setting.toMap(), settings);
      expect(GStorage.video.toMap(), player);
      expect(
        GStorage.localCache.get(LocalCacheKey.mixinKey),
        'target-cache-only',
      );
      final restored = GStorage.localCache.get(ruleKey) as RuleFilter;
      expect(restored.dmFilterString, ['muted phrase']);
      expect(restored.dmUid, {'1234abc'});
      expect(restored.dmRegExp.single.hasMatch('BLOCKED123'), isTrue);
      expect(restored.dmRegExp.single.hasMatch('prefix BLOCKED123'), isFalse);
    },
  );

  test('invalid backup fails before either box or rules changes', () async {
    final settings = {
      SettingBoxKey.harmonyImmersive: true,
      SettingBoxKey.showMedal: true,
    };
    final player = {VideoBoxKey.playSpeedDefault: 2.0};
    final rules = RuleFilter(['original'], [], {});
    await GStorage.setting.putAll(settings);
    await GStorage.video.putAll(player);
    await GStorage.localCache.put(ruleKey, rules);
    final invalid = [
      '[invalid json',
      jsonEncode({
        'setting': {SettingBoxKey.harmonyImmersive: false},
      }),
      jsonEncode({'setting': [], 'video': player}),
      jsonEncode({
        'setting': {
          SettingBoxKey.navBarSort: [999],
        },
        'video': player,
      }),
      jsonEncode({
        'setting': {
          SettingBoxKey.tabBarSort: [999],
        },
        'video': player,
      }),
      jsonEncode({
        'setting': {SettingBoxKey.uiScale: 1000000},
        'video': player,
      }),
      jsonEncode({
        'setting': {SettingBoxKey.enableSlideFS: 'bad'},
        'video': player,
      }),
      jsonEncode({
        'setting': {SettingBoxKey.showMedal: 'bad'},
        'video': player,
      }),
      jsonEncode({
        'setting': settings,
        'video': {VideoBoxKey.cacheVideoFit: 99},
      }),
      jsonEncode({
        'setting': settings,
        'video': player,
        'danmakuRules': {
          'keywords': [],
          'patterns': ['['],
          'userHashes': [],
        },
      }),
    ];
    for (final backup in invalid) {
      await expectLater(
        GStorage.importAllSettings(backup),
        throwsFormatException,
      );
      expect(GStorage.setting.toMap(), settings);
      expect(GStorage.video.toMap(), player);
      expect(GStorage.localCache.get(ruleKey), same(rules));
    }
  });

  test(
    'restore rolls back settings and rules if a later write fails',
    () async {
      final settings = {
        SettingBoxKey.harmonyImmersive: true,
        'onlyOnTarget': 1,
      };
      final player = {VideoBoxKey.playSpeedDefault: 1.25};
      final rules = RuleFilter(['original'], [], {});
      await GStorage.setting.putAll(settings);
      await GStorage.video.putAll(player);
      await GStorage.localCache.put(ruleKey, rules);
      final backup = {
        'setting': {
          SettingBoxKey.harmonyImmersive: false,
          'onlyInBackup': true,
        },
        'video': {
          VideoBoxKey.playSpeedDefault: 2.0,
          VideoBoxKey.cacheVideoFit: 0,
        },
        'danmakuRules': {
          'keywords': ['replacement'],
          'patterns': [],
          'userHashes': [],
        },
      };
      for (final failingBox in [playerBox, cacheBox]) {
        failingBox.failNextWrite = true;
        await expectLater(
          GStorage.importAllJsonSettings(backup),
          throwsA(isA<FileSystemException>()),
        );
        expect(GStorage.setting.toMap(), settings);
        expect(GStorage.video.toMap(), player);
        expect(GStorage.localCache.get(ruleKey), same(rules));
      }
    },
  );

  test(
    'legacy backup leaves local rules and falls back for unavailable font',
    () async {
      final rules = RuleFilter(['target-rule'], [], {});
      await GStorage.localCache.put(ruleKey, rules);
      await GStorage.importAllJsonSettings({
        'setting': {
          SettingBoxKey.appFont: '123/FixtureFont',
          SettingBoxKey.appFontWeightV2: 4,
        },
        'video': {VideoBoxKey.playSpeedDefault: 2},
      });
      expect(GStorage.setting.get(SettingBoxKey.appFont), isNull);
      expect(GStorage.setting.get(SettingBoxKey.appFontWeightV2), 4);
      expect(GStorage.video.get(VideoBoxKey.playSpeedDefault), isA<double>());
      expect(GStorage.localCache.get(ruleKey), same(rules));
      await GStorage.importAllJsonSettings({
        'setting': {},
        'video': {},
        'danmakuRules': null,
      });
      expect(GStorage.localCache.get(ruleKey), isNull);
    },
  );
}
