import 'dart:io';
import 'package:PiliPlus/harmony_adapt/player_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  setUp(
    () async => root = await Directory.systemTemp.createTemp('player-cache-'),
  );
  tearDown(() async => root.delete(recursive: true));

  test(
    'creates sandbox packet cache and preserves existing files on reuse',
    () async {
      final options = await harmonyPlayerCacheOptions('${root.path}/sandbox');
      final directory = Directory(options['demuxer-cache-dir']!);
      expect(await directory.exists(), true);
      final retained = File('${directory.path}/active-packets');
      await retained.writeAsString('existing player data');
      expect(await harmonyPlayerCacheOptions('${root.path}/sandbox'), options);
      expect(await retained.readAsString(), 'existing player data');
    },
  );

  test(
    'unavailable disk directory falls back without preventing playback',
    () async {
      final file = File('${root.path}/blocked');
      await file.writeAsString('keep');
      expect(await harmonyPlayerCacheOptions(file.path), {
        'cache-on-disk': 'no',
      });
      expect(await file.readAsString(), 'keep');
    },
  );
}
