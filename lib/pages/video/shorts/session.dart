import 'dart:async';
import 'package:flutter/foundation.dart';

@immutable
class ShortVideoEntry {
  const ShortVideoEntry({
    required this.bvid,
    this.aid,
    this.cid,
    this.cover,
    this.title,
  });
  final String bvid;
  final int? aid;
  final int? cid;
  final String? cover;
  final String? title;
}

/// One playback owner, a lightweight metadata queue, and serialized switches.
/// No offscreen player instances or hidden background video downloads.
class ShortVideoSession extends ChangeNotifier {
  ShortVideoSession({
    required ShortVideoEntry initial,
    required this.loadRelated,
    required this.play,
  }) : _entries = [initial];
  final Future<List<ShortVideoEntry>> Function(String bvid) loadRelated;
  final Future<bool> Function(ShortVideoEntry entry) play;
  final List<ShortVideoEntry> _entries;
  final Set<String> _fetched = {};
  int _index = 0;
  bool _disposed = false;
  bool switching = false;
  bool interacting = false;
  bool loading = false;
  String? error;
  List<ShortVideoEntry> get entries => List.unmodifiable(_entries);
  int get index => _index;
  ShortVideoEntry get current => _entries[_index];
  bool get hasNext => _index + 1 < _entries.length;

  Future<void> loadMore() async {
    if (_disposed || loading) return;
    // Each seed is fetched once after success; failures stay retryable.
    final seeds = [current, ..._entries.reversed];
    final seed = seeds.where((e) => !_fetched.contains(e.bvid)).firstOrNull;
    if (seed == null) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final incoming = await loadRelated(seed.bvid);
      if (_disposed) return;
      final seen = _entries.map((e) => e.bvid).toSet();
      for (final entry in incoming) {
        if (entry.bvid.isNotEmpty && seen.add(entry.bvid)) _entries.add(entry);
      }
      _fetched.add(seed.bvid);
    } catch (_) {
      if (!_disposed) error = '暂时无法加载更多视频，点击重试';
    } finally {
      if (!_disposed) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> select(int next) async {
    if (_disposed ||
        switching ||
        interacting ||
        next < 0 ||
        next >= _entries.length)
      return false;
    if (next == _index) return true;
    switching = true;
    error = null;
    notifyListeners();
    try {
      final accepted = await play(_entries[next]);
      if (_disposed) return false;
      if (accepted)
        _index = next;
      else
        error = '视频切换失败，已保留当前视频，请重试';
      return accepted;
    } catch (_) {
      if (!_disposed) error = '视频切换失败，请重试';
      return false;
    } finally {
      if (!_disposed) {
        switching = false;
        notifyListeners();
      }
    }
  }

  /// Keep account actions associated with the visible video while awaiting
  /// their response. Modal actions also retain their existing navigation flow.
  Future<void> interact(FutureOr<void> Function() action) async {
    if (_disposed || switching || interacting) return;
    interacting = true;
    notifyListeners();
    try {
      await action();
    } finally {
      if (!_disposed) {
        interacting = false;
        notifyListeners();
      }
    }
  }

  /// Episode changes made through the existing collection panel are reflected
  /// in the current feed entry without discarding previous/next navigation.
  void syncCurrent(ShortVideoEntry entry) {
    if (_disposed || switching) return;
    _entries[_index] = entry;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
