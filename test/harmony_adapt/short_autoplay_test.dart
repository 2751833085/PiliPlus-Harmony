import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:PiliPlus/pages/video/controller.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'short feed enables autoplay on entry and next source without changing ordinary preference',
    () async {
      final temp = await Directory.systemTemp.createTemp('shorts-autoplay-');
      Hive.init(temp.path);
      GStorage.setting = await Hive.openBox('setting');
      GStorage.localCache = await Hive.openBox('cache');
      GStorage.video = await Hive.openBox('video');
      await GStorage.setting.put(SettingBoxKey.autoPlayEnable, false);
      final video = VideoDetailController()..isFileSource = false;
      expect(video.autoPlay, isFalse);
      video.shortVideoMode = true;
      expect(video.autoPlay, isTrue);
      expect(Pref.autoPlayEnable, isFalse);
      // Failed playback/manual pause of this item must not disable the next one.
      video.autoPlay = false;
      video.onReset();
      expect(video.autoPlay, isTrue);
      video.shortVideoMode = false;
      video.autoPlay = false;
      video.onReset();
      expect(video.autoPlay, isFalse);
      expect(Pref.autoPlayEnable, isFalse);
      await Hive.close();
      await temp.delete(recursive: true);
    },
  );
}
