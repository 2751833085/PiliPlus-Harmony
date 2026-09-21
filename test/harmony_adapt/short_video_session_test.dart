import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/pages/video/shorts/session.dart';

void main() {
  const a = ShortVideoEntry(bvid: 'a');
  const b = ShortVideoEntry(bvid: 'b');
  test(
    'feed deduplicates, preserves previous entries and serializes switches',
    () async {
      final playback = Completer<bool>();
      var requests = 0;
      final session = ShortVideoSession(
        initial: a,
        loadRelated: (_) async {
          requests++;
          return [a, b, b, const ShortVideoEntry(bvid: '')];
        },
        play: (_) => playback.future,
      );
      await session.loadMore();
      expect(session.entries.map((e) => e.bvid), ['a', 'b']);
      final pending = session.select(1);
      expect(await session.select(1), isFalse);
      expect(session.index, 0);
      playback.complete(true);
      expect(await pending, isTrue);
      expect(session.index, 1);
      expect(requests, 1);
      session.dispose();
    },
  );
  test(
    'network and playback errors remain retryable and do not advance the queue',
    () async {
      var fail = true;
      final session = ShortVideoSession(
        initial: a,
        loadRelated: (_) async {
          if (fail) throw StateError('offline');
          return [b];
        },
        play: (_) async => false,
      );
      await session.loadMore();
      expect(session.error, isNotNull);
      fail = false;
      await session.loadMore();
      expect(session.hasNext, isTrue);
      expect(await session.select(1), isFalse);
      expect(session.current.bvid, 'a');
      expect(session.switching, isFalse);
      session.dispose();
    },
  );
  test(
    'leaving while recommendations or playback are pending discards callbacks',
    () async {
      final load = Completer<List<ShortVideoEntry>>();
      final session = ShortVideoSession(
        initial: a,
        loadRelated: (_) => load.future,
        play: (_) async => true,
      );
      final pending = session.loadMore();
      session.dispose();
      load.complete([b]);
      await pending;
      expect(session.entries.length, 1);
      final play = Completer<bool>();
      final other = ShortVideoSession(
        initial: a,
        loadRelated: (_) async => [b],
        play: (_) => play.future,
      );
      await other.loadMore();
      final change = other.select(1);
      other.dispose();
      play.complete(true);
      expect(await change, isFalse);
      expect(other.index, 0);
    },
  );
  test(
    'collection selection updates only the active entry and preserves navigation',
    () async {
      final session = ShortVideoSession(
        initial: a,
        loadRelated: (_) async => [b],
        play: (_) async => true,
      );
      await session.loadMore();
      session.syncCurrent(const ShortVideoEntry(bvid: 'collection', cid: 42));
      expect(session.current.cid, 42);
      expect(session.entries.last.bvid, 'b');
      await session.select(1);
      await session.select(0);
      expect(session.current.bvid, 'collection');
      session.dispose();
    },
  );
  test('failed account interaction releases the gesture lock', () async {
    final session = ShortVideoSession(
      initial: a,
      loadRelated: (_) async => [b],
      play: (_) async => true,
    );
    await session.loadMore();
    await expectLater(
      session.interact(() => throw StateError('offline')),
      throwsStateError,
    );
    expect(session.interacting, isFalse);
    expect(await session.select(1), isTrue);
    session.dispose();
  });
}
