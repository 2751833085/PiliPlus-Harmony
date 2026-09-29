import 'dart:async';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/pages/rcmd/controller.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/memory_box.dart';

class _Recommendations extends RcmdController {
  final requests = <Completer<LoadingState>>[];
  @override
  Future<LoadingState> customGetData() {
    final request = Completer<LoadingState>();
    requests.add(request);
    return request.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GStorage.setting = MemoryBox());
  for (final initial in [true, false]) {
    test(
      'first pull wins over ${initial ? "initial load" : "pagination"}',
      () async {
        final controller = _Recommendations()..enableSaveLastData = false;
        addTearDown(controller.scrollController.dispose);
        if (!initial) controller.loadingState.value = Success(['visible']);
        final previous = controller.queryData(initial);
        final refresh = controller.onRefresh();
        expect(controller.requests.length, 2);
        expect(identical(controller.onRefresh(), refresh), isTrue);
        controller.requests[1].complete(Success(['refreshed']));
        await refresh;
        controller.requests[0].complete(Success(['obsolete']));
        await previous;
        expect(controller.loadingState.value.dataOrNull, ['refreshed']);
        expect(controller.isLoading, isFalse);
        expect(controller.page, 1);
        final next = controller.onRefresh();
        controller.requests[2].complete(Success(['next']));
        await next;
        expect(controller.loadingState.value.dataOrNull, ['next']);
      },
    );
  }
}
