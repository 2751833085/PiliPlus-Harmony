import 'package:PiliPlus/http/loading_state.dart';

int recommendationBatchSize(int columns) => (columns * 10).clamp(24, 60);

Future<LoadingState<List<T>>> collectRecommendationBatch<T>({
  required int target,
  required Future<LoadingState<List<T>>> Function() fetch,
  required String? Function(T) keyOf,
  int parallelism = 1,
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

  while (attempts < 4 && items.length < target) {
    // App feeds return small pages. At most two independent requests overlap;
    // preserve request order even when network responses finish out of order.
    final count = parallelism.clamp(1, 2).clamp(1, 4 - attempts);
    attempts += count;
    final results = await Future.wait(List.generate(count, (_) => request()));
    final before = items.length;
    LoadingState<List<T>>? failure;
    for (final result in results) {
      if (result case Success(:final response)) {
        for (final item in response) {
          final key = keyOf(item);
          if (key == null || seen.add(key)) items.add(item);
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
