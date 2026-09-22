import 'dart:async';
import 'dart:io';
import 'package:PiliPlus/common/widgets/pair.dart';
import 'package:PiliPlus/models/common/sponsor_block/segment_model.dart';
import 'package:PiliPlus/models/common/sponsor_block/segment_type.dart';
import 'package:PiliPlus/models/common/sponsor_block/skip_type.dart';
import 'package:PiliPlus/models_new/sponsor_block/segment_item.dart';
import 'package:PiliPlus/pages/sponsor_block/block_mixin.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';
import 'package:media_kit/media_kit.dart';

void main() {
  late Directory temp;
  setUpAll(() async {
    temp = await Directory.systemTemp.createTemp('skip-regression-');
    Hive.init(temp.path);
    GStorage.setting = await Hive.openBox('setting');
    await GStorage.setting.putAll({'blockTrack': false, 'blockToast': false});
  });
  tearDownAll(() async {
    await Hive.close();
    await temp.delete(recursive: true);
  });
  test(
    'SponsorBlock keeps automatic, once-only and manual seeks after timeline changes; reset removes old listeners',
    () async {
      final h = _Block();
      await h.handleSBData([
        SegmentItemModel(
          category: 'sponsor',
          segment: [10000, 20000],
          uuid: 'fixture-once',
          videoDuration: 100000,
        ),
        SegmentItemModel(
          category: 'intro',
          segment: [30000, 40000],
          uuid: 'fixture-always',
          videoDuration: 100000,
        ),
        SegmentItemModel(
          category: 'interaction',
          segment: [50000, 60000],
          uuid: 'fixture-manual',
          videoDuration: 100000,
        ),
      ]);
      expect(h.segmentProgressList.map((e) => (e.start, e.end)), [
        (.1, .2),
        (.3, .4),
        (.5, .6),
      ]);
      Future<void> at(int seconds) async {
        h.player.events.add(Duration(seconds: seconds));
        await Future<void>.delayed(Duration.zero);
      }

      await at(9);
      expect(h.seeks, [const Duration(seconds: 20)]);
      await at(1);
      await at(9);
      expect(h.seeks.length, 1);
      await at(29);
      await at(1);
      await at(29);
      expect(h.seeks.length, 3);
      expect(h.seeks.last, const Duration(seconds: 40));
      await at(49);
      expect(h.manual.length, 1);
      expect(h.seeks.length, 3);
      await h.onSkip(h.manual.single, isSeek: false);
      expect(h.seeks.last, const Duration(seconds: 60));
      h.resetBlock();
      expect(h.segmentProgressList, isEmpty);
      expect(h.blockListener, isNull);
      await at(9);
      expect(h.seeks.length, 4);
      h.onClose();
      await h.player.events.close();
    },
  );
}

class _Config with BlockConfigMixin {
  @override
  bool get enableBlock => true;
  @override
  bool get enablePgcSkip => false;
  @override
  double get blockLimit => 0;
  @override
  Set<String> get enableList => {'sponsor', 'intro', 'interaction'};
  @override
  List<Color> get blockColor => [
    for (final _ in SegmentType.values) Colors.green,
  ];
  @override
  List<Pair<SegmentType, SkipType>> get blockSettings => [
    for (final type in SegmentType.values)
      Pair(
        first: type,
        second: switch (type) {
          SegmentType.sponsor => SkipType.skipOnce,
          SegmentType.intro => SkipType.alwaysSkip,
          SegmentType.interaction => SkipType.skipManually,
          _ => SkipType.disable,
        },
      ),
  ];
}

class _Block extends GetxController with BlockMixin {
  @override
  final blockConfig = _Config();
  @override
  final _Player player = _Player();
  @override
  bool get autoPlay => false;
  @override
  int get timeLength => 100000;
  @override
  bool get preInitPlayer => true;
  @override
  int get currPosInMilliseconds => 0;
  @override
  bool get isUgc => true;
  final seeks = <Duration>[];
  final manual = <SegmentModel>[];
  @override
  Future<void> seekTo(Duration duration, {required bool isSeek}) async {
    seeks.add(duration);
  }

  @override
  void onAddItem(Object item) {
    manual.add(item as SegmentModel);
  }
}

class _Player implements Player {
  final events = StreamController<Duration>();
  @override
  PlayerStream get stream => _Stream(events.stream);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Stream implements PlayerStream {
  _Stream(this.position);
  @override
  final Stream<Duration> position;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
