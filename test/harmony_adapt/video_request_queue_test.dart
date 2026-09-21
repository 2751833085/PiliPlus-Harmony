import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/pages/video/shorts/request_queue.dart';
import 'package:PiliPlus/pages/common/common_list_controller.dart';
import 'package:PiliPlus/http/loading_state.dart';

void main() {
  test('latest source wins, native initializations never overlap', () async {
    final queue = VideoRequestQueue();
    final first = Completer<void>();
    final applied = <String>[];
    var active = 0;
    var peak = 0;
    Future<void> request(String id, [Future<void>? wait]) =>
        queue.run((ticket) async {
          active++;
          if (active > peak) peak = active;
          if (wait != null) await wait;
          if (queue.isCurrent(ticket)) applied.add(id);
          active--;
        });
    final a = request('a', first.future);
    await Future<void>.delayed(Duration.zero);
    final b = request('b');
    final c = request('c');
    first.complete();
    await Future.wait([a, b, c]);
    expect(applied, ['c']);
    expect(peak, 1);
    queue.dispose();
  });
  test('queue recovers from failure and discards disposed callbacks', () async {
    final queue = VideoRequestQueue();
    await expectLater(
      queue.run((_) async => throw StateError('offline')),
      throwsStateError,
    );
    var count = 0;
    await queue.run((_) async {
      count++;
    });
    final gate = Completer<void>();
    final pending = queue.run((ticket) async {
      await gate.future;
      if (queue.isCurrent(ticket)) count++;
    });
    await Future<void>.delayed(Duration.zero);
    queue.dispose();
    gate.complete();
    await pending;
    expect(count, 1);
  });
  test('old comments cannot overwrite a newly selected video', () async {
    final controller = _ListFixture();
    final old = controller.queryData();
    controller.invalidateRequests();
    final next = controller.queryData();
    controller.pending[1].complete(Success(['new video comment']));
    await next;
    controller.pending[0].complete(Success(['old video comment']));
    await old;
    expect(controller.loadingState.value.dataOrNull, ['new video comment']);
    expect(controller.isLoading, isFalse);
    controller.scrollController.dispose();
  });
}

class _ListFixture extends CommonListController<List<String>, String> {
  final pending = <Completer<LoadingState<List<String>>>>[];
  @override
  Future<LoadingState<List<String>>> customGetData() {
    final request = Completer<LoadingState<List<String>>>();
    pending.add(request);
    return request.future;
  }
}
