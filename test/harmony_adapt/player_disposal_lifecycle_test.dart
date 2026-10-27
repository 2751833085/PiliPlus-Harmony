import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'helpers/memory_box.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    GStorage.setting = MemoryBox();
    GStorage.video = MemoryBox();
    GStorage.localCache = MemoryBox();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
          'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
          (_) async => const StandardMessageCodec().encodeMessage([null]),
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });
  test(
    'a new video never reuses a player whose asynchronous cleanup started',
    () async {
      final first = PlPlayerController.getInstance();
      final closing = first.dispose();
      final next = PlPlayerController.getInstance();
      expect(identical(first, next), isFalse);
      expect(identical(closing, first.dispose()), isTrue);
      await closing;
      final retained = PlPlayerController.getInstance();
      expect(
        identical(next, retained),
        isTrue,
        reason: 'the previous cleanup must not erase the new singleton',
      );
      await retained.dispose();
      await next.dispose();
    },
  );
}
