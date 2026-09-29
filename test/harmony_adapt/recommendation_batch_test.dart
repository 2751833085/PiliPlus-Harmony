import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/pages/rcmd/refresh_batch.dart';

void main() {
  test(
    'parallel batches overlap, preserve order and respect the request limit',
    () async {
      final first = Completer<LoadingState<List<int>>>();
      final second = Completer<LoadingState<List<int>>>();
      var calls = 0;
      final pending = collectRecommendationBatch<int>(
        target: 3,
        parallelism: 2,
        keyOf: (value) => '$value',
        fetch: () => calls++ == 0 ? first.future : second.future,
      );
      expect(calls, 2);
      second.complete(const Success([2, 3]));
      first.complete(const Success([1, 2]));
      expect((await pending).data, [1, 2, 3]);
      expect(calls, 2);
    },
  );
  test(
    'parallel request failure does not discard the other successful page',
    () async {
      var calls = 0;
      final result = await collectRecommendationBatch<int>(
        target: 40,
        parallelism: 2,
        keyOf: (value) => '$value',
        fetch: () async =>
            calls++ == 0 ? const Error('offline') : const Success([9]),
      );
      expect(result.data, [9]);
      expect(calls, 2);
    },
  );

  test('batch size follows columns with a bounded maximum', () {
    expect(recommendationBatchSize(2), 24);
    expect(recommendationBatchSize(4), 40);
    expect(recommendationBatchSize(12), 60);
  });
  test(
    'fills a short response and removes overlapping recommendations',
    () async {
      var calls = 0;
      final result = await collectRecommendationBatch<int>(
        target: 4,
        keyOf: (value) => '$value',
        fetch: () async => Success(calls++ == 0 ? [1, 2] : [2, 3, 4]),
      );
      expect(result.data, [1, 2, 3, 4]);
      expect(calls, 2);
    },
  );
  test('keeps loaded videos when a supplemental request fails', () async {
    var calls = 0;
    final result = await collectRecommendationBatch<int>(
      target: 20,
      keyOf: (value) => '$value',
      fetch: () async =>
          calls++ == 0 ? const Success([1]) : const Error('network'),
    );
    expect(result.data, [1]);
    expect(calls, 2);
  });
  test('stops on repeated responses and caps short unique responses', () async {
    var calls = 0;
    await collectRecommendationBatch<int>(
      target: 60,
      keyOf: (value) => '$value',
      fetch: () async {
        calls++;
        return const Success([1]);
      },
    );
    expect(calls, 2);
    calls = 0;
    await collectRecommendationBatch<int>(
      target: 60,
      keyOf: (value) => '$value',
      fetch: () async => Success([calls++]),
    );
    expect(calls, 4);
  });
}
