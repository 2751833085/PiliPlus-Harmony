import 'dart:async';

import 'package:PiliPlus/http/ai_conclusion_request.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models_new/video/video_ai_conclusion/data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const generating = Success(AiConclusionData(code: 1));

  test('generation is polled until real content arrives', () async {
    var calls = 0;
    final ready = Success(
      AiConclusionData.fromJson({
        'code': 0,
        'model_result': {'summary': '已生成的视频总结'},
      }),
    );
    final result = await AiConclusionRequest().run(
      () async => ++calls < 3 ? generating : ready,
      interval: Duration.zero,
    );
    expect(result, same(ready));
    expect(calls, 3);
  });

  test('generation has a strict request limit', () async {
    var calls = 0;
    final result = await AiConclusionRequest().run(() async {
      calls++;
      return generating;
    }, interval: Duration.zero);
    expect(calls, 10);
    expect(result?.dataOrNull?.unavailableMessage, contains('超时'));
  });

  test(
    'unsupported, empty, login and rate-limit responses do not retry',
    () async {
      for (final response in <LoadingState<AiConclusionData>>[
        const Success(AiConclusionData(code: -1)),
        const Success(AiConclusionData(code: 0)),
        const Error('登录失效', code: -101),
        const Error('请求受限', code: -412),
      ]) {
        var calls = 0;
        final result = await AiConclusionRequest().run(() async {
          calls++;
          return response;
        }, interval: Duration.zero);
        expect(result, same(response));
        expect(calls, 1);
      }
    },
  );

  test(
    'cancel releases waiting immediately and discards late responses',
    () async {
      final request = AiConclusionRequest();
      final pending = Completer<LoadingState<AiConclusionData>>();
      var calls = 0;
      final result = request.run(() {
        calls++;
        return pending.future;
      });
      request.cancel();
      expect(await result, isNull);
      pending.complete(generating);
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
    },
  );

  test(
    'changing video discards stale results and prevents further requests',
    () async {
      var current = true;
      var calls = 0;
      final result = await AiConclusionRequest().run(() async {
        calls++;
        current = false;
        return generating;
      }, isCurrent: () => current);
      expect(result, isNull);
      expect(calls, 1);
    },
  );
}
