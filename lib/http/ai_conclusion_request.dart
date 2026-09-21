import 'dart:async';

import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models_new/video/video_ai_conclusion/data.dart';

/// Bilibili's web assistant retries nested code 1 every five seconds, up to
/// ten requests. Other statuses and transport errors must not be retried.
class AiConclusionRequest {
  final _cancelled = Completer<void>();

  bool get isCancelled => _cancelled.isCompleted;

  void cancel() {
    if (!isCancelled) _cancelled.complete();
  }

  Future<LoadingState<AiConclusionData>?> run(
    Future<LoadingState<AiConclusionData>> Function() fetch, {
    bool Function()? isCurrent,
    Duration interval = const Duration(seconds: 5),
    int maxAttempts = 10,
  }) async {
    assert(maxAttempts > 0);
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (isCancelled || isCurrent?.call() == false) return null;
      final result = await Future.any<LoadingState<AiConclusionData>?>([
        fetch(),
        _cancelled.future.then((_) => null),
      ]);
      if (isCancelled || isCurrent?.call() == false) return null;
      if (result case Success(:final response)) {
        if (!response.isGenerating || attempt == maxAttempts - 1) return result;
      } else {
        return result;
      }
      await Future.any<void>([
        Future<void>.delayed(interval),
        _cancelled.future,
      ]);
    }
    return null;
  }
}
