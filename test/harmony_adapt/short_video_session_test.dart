import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/pages/video/shorts/session.dart';

void main() {
  const a = ShortVideoEntry(bvid: 'a');
  const b = ShortVideoEntry(bvid: 'b');
  test(
    'first-page refresh replaces the first video and discards stale metadata',
    () async {
      final old = Completer<List<ShortVideoEntry>>();
      final play = Completer<bool>();
      final session = ShortVideoSession(
        initial: a,
        loadRelated: (_) => old.future,
        loadFresh: () async => [a, b, b, const ShortVideoEntry(bvid: 'c')],
        play: (_) => play.future,
      );
      final stale = session.loadMore();
      final refreshing = session.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(session.current.bvid, 'a');
      expect(await session.refresh(), isFalse);
      expect(await session.select(1), isFalse);
      play.complete(true);
      expect(await refreshing, isTrue);
      old.complete([const ShortVideoEntry(bvid: 'stale')]);
      await stale;
      expect(session.entries.map((e) => e.bvid), ['b', 'c']);
      expect(session.index, 0);
      expect(session.refreshing, isFalse);
      session.dispose();
    },
  );
  test(
    'failed/empty refresh retains first video and later pages do not refresh',
    () async {
      var plays = 0;
      var fail = true;
      final session = ShortVideoSession(
        initial: a,
        loadRelated: (_) async => [b],
        loadFresh: () async {
          if (fail) throw StateError('offline');
          return [a];
        },
        play: (_) async {
          plays++;
          return true;
        },
      );
      await session.loadMore();
      expect(await session.refresh(), isFalse);
      fail = false;
      expect(await session.refresh(), isFalse);
      expect(plays, 0);
      expect(session.current.bvid, 'a');
      expect(session.error, isNotNull);
      await session.select(1);
      expect(await session.refresh(), isFalse);
      expect(session.current.bvid, 'b');
      session.dispose();
    },
  );
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
  test(
    'entry snapshots are reused for state changes and replaced after queue edits',
    () async {
      final session = ShortVideoSession(
        initial: a,
        loadRelated: (_) async => [b],
        loadFresh: () async => const [ShortVideoEntry(bvid: 'fresh')],
        play: (_) async => true,
      );
      addTearDown(session.dispose);
      final initial = session.entries;
      expect(session.entries, same(initial));
      expect(() => initial.add(b), throwsUnsupportedError);
      await session.loadMore();
      final loaded = session.entries;
      expect(loaded, isNot(same(initial)));
      expect(initial.map((e) => e.bvid), ['a']);
      expect(loaded.map((e) => e.bvid), ['a', 'b']);
      await session.select(1);
      await session.interact(() {});
      expect(session.entries, same(loaded));
      session.syncCurrent(const ShortVideoEntry(bvid: 'episode', cid: 42));
      final synced = session.entries;
      expect(synced.map((e) => e.bvid), ['a', 'episode']);
      expect(loaded.map((e) => e.bvid), ['a', 'b']);
      await session.select(0);
      expect(await session.dismissCurrent(), isTrue);
      expect(session.entries.map((e) => e.bvid), ['episode']);
      expect(synced.map((e) => e.bvid), ['a', 'episode']);
      final dismissed = session.entries;
      expect(await session.refresh(), isTrue);
      expect(session.entries.map((e) => e.bvid), ['fresh']);
      expect(dismissed.map((e) => e.bvid), ['episode']);
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
