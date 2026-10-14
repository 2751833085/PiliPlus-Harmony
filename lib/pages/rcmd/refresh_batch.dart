import 'package:PiliPlus/http/loading_state.dart';

int recommendationBatchSize(int columns, {bool initialLoad = false}) =>
    initialLoad ? 16 : (columns * 4).clamp(8, 20);

Future<LoadingState<List<T>>> collectRecommendationBatch<T>({
  required int target,
  required Future<LoadingState<List<T>>> Function() fetch,
  required String? Function(T) keyOf,
  int parallelism = 1,
  int maxRequests = 4,
  bool limitToTarget = false,
}) async {
  final items = <T>[];
  final seen = <String>{};
  var attempts = 0;
  Future<LoadingState<List<T>>> request() async {
    try {
      return await fetch();
    } catch (error) {
      return Error(error.toString());
    }
  }

  final limit = maxRequests.clamp(1, 4);
  while (attempts < limit && items.length < target) {
    // App feeds return small pages. At most two independent requests overlap;
    // preserve request order even when network responses finish out of order.
    final count = parallelism.clamp(1, 2).clamp(1, limit - attempts);
    attempts += count;
    final results = await Future.wait(List.generate(count, (_) => request()));
    final before = items.length;
    LoadingState<List<T>>? failure;
    for (final result in results) {
      if (result case Success(:final response)) {
        for (final item in response) {
          final key = keyOf(item);
          if (key == null || seen.add(key)) {
            if (!limitToTarget || items.length < target) items.add(item);
          }
        }
      } else {
        failure = result;
      }
    }
    if (failure != null) return items.isEmpty ? failure : Success(items);
    if (items.length == before) break;
  }
  return Success(items);
}
