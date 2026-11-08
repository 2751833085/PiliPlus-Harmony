import 'package:PiliPlus/models_new/video/video_detail/data.dart';
import 'package:PiliPlus/services/audio_handler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final clear in [false, true]) {
    test(
      'late media metadata stays discarded after ${clear ? 'clear' : 'route disposal'}',
      () async {
        final handler = VideoPlayerServiceHandler(enableBackgroundPlay: true);
        addTearDown(handler.clear);
        handler.onVideoDetailChange(VideoDetailData(title: 'old'), 1, 'closed');
        if (clear) {
          handler.clear();
        } else {
          handler.onVideoDetailDispose('closed');
        }

        // Empty cover art needs no I/O, but still completes on a later microtask.
        await pumpEventQueue();
        expect(handler.mediaItem.valueOrNull, isNull);
      },
    );
  }

  test('superseded episodes never publish old metadata', () async {
    final handler = VideoPlayerServiceHandler(enableBackgroundPlay: true);
    addTearDown(handler.clear);
    final titles = <String>[];
    final sub = handler.mediaItem.listen((item) {
      if (item != null) titles.add(item.title);
    });
    addTearDown(sub.cancel);

    handler.onVideoDetailChange(
      VideoDetailData(title: 'older episode'),
      1,
      'route',
    );
    handler.onVideoDetailChange(
      VideoDetailData(title: 'newer episode'),
      2,
      'route',
    );
    await pumpEventQueue();

    expect(titles, ['newer episode']);
    expect(handler.mediaItem.valueOrNull?.id, '2route');
    handler.onVideoDetailDispose('route');
    expect(handler.mediaItem.valueOrNull, isNull);
  });

  test(
    'updating a covered video preserves foreground media and restores latest metadata on return',
    () async {
      final handler = VideoPlayerServiceHandler(enableBackgroundPlay: true);
      addTearDown(handler.clear);
      handler.onVideoDetailChange(
        VideoDetailData(title: 'underlying'),
        1,
        'first',
      );
      handler.onVideoDetailChange(
        VideoDetailData(title: 'foreground'),
        2,
        'second',
      );
      await pumpEventQueue();
      expect(handler.mediaItem.valueOrNull?.title, 'foreground');

      handler.onVideoDetailChange(
        VideoDetailData(title: 'updated underlying'),
        3,
        'first',
      );
      await pumpEventQueue();
      expect(handler.mediaItem.valueOrNull?.title, 'foreground');

      handler.onVideoDetailDispose('second');
      expect(handler.mediaItem.valueOrNull?.title, 'updated underlying');
    },
  );
}
