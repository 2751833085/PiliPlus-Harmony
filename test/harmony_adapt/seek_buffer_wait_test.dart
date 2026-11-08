import 'dart:async';

import 'package:PiliPlus/plugin/pl_player/models/seek_buffer_wait.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('seek timeout releases a silent source subscription', () async {
    var cancelled = false;
    final buffer = StreamController<Duration>(onCancel: () => cancelled = true);
    final pending = waitForSeekBuffer(buffer.stream, () => true);
    expect(cancelled, isFalse);
    expect(
      await pending.timeout(const Duration(seconds: 2)),
      isTrue,
      reason: 'a current seek may proceed without a buffer event',
    );
    expect(
      cancelled,
      isTrue,
      reason: 'timeout must cancel the native stream listener',
    );
    await buffer.close();
  });

  test(
    'closing the old buffer while switching videos does not seek the new source',
    () async {
      var current = true;
      final buffer = StreamController<Duration>();
      final pending = waitForSeekBuffer(buffer.stream, () => current);
      current = false;
      await buffer.close();
      expect(await pending, isFalse);
    },
  );

  test(
    'a buffer event only advances the seek that still owns the source',
    () async {
      var active = true;
      final buffer = StreamController<Duration>();
      final pending = waitForSeekBuffer(buffer.stream, () => active);
      active = false;
      buffer.add(const Duration(seconds: 2));
      expect(await pending, isFalse);
      await buffer.close();
    },
  );
}
