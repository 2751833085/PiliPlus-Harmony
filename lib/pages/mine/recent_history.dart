import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models_new/history/data.dart';
import 'package:PiliPlus/models_new/history/list.dart';
import 'package:flutter/foundation.dart';

/// A bounded preview, isolated from the full history page and its edit state.
class RecentHistory extends ChangeNotifier {
  bool enabled = false;
  Object? _account;
  bool get loggedIn => _account != null;
  bool loading = false;
  String? error;
  List<HistoryItemModel> items = const [];
  Future<LoadingState<HistoryData>> Function()? _load;
  int _generation = 0;
  bool _disposed = false;

  void configure({
    required bool enabled,
    required Object? account,
    required Future<LoadingState<HistoryData>> Function() load,
  }) {
    if (_disposed) return;
    if (this.enabled == enabled && identical(_account, account)) return;
    _generation++;
    this.enabled = enabled;
    _account = account;
    _load = load;
    items = const [];
    error = null;
    loading = false;
    notifyListeners();
    if (enabled && loggedIn) refresh();
  }

  Future<void> refresh() async {
    if (_disposed || !enabled || !loggedIn || loading) return;
    final generation = ++_generation;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await _load!();
      if (_disposed || generation != _generation) return;
      if (result case Success(:final response)) {
        items = List.unmodifiable((response.list ?? []).take(10));
      } else {
        error = '观看历史暂时无法加载，请重试';
      }
    } catch (_) {
      if (_disposed || generation != _generation) return;
      error = '观看历史暂时无法加载，请重试';
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
