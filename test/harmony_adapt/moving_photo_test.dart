import 'dart:async';

import 'package:PiliPlus/harmony_adapt/harmony_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('harmonyChannel');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('moving photo waits for native save before reporting success', () async {
    final nativeSave = Completer<bool>();
    MethodCall? request;
    messenger.setMockMethodCallHandler(channel, (call) {
      request = call;
      return nativeSave.future;
    });
    var completed = false;
    final pending =
        HarmonyChannel.saveMovingPhoto(
          imagePath: '/cache/cover.webp',
          videoPath: '/cache/motion.mp4',
        ).then((result) {
          completed = true;
          return result;
        });
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);
    expect(request!.method, 'saveMovingPhoto');
    expect(request!.arguments, {
      'imagePath': '/cache/cover.webp',
      'videoPath': '/cache/motion.mp4',
    });
    nativeSave.complete(true);
    expect(await pending, isTrue);
  });

  test('cancel is not reported as a successful save', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => false);
    expect(
      await HarmonyChannel.saveMovingPhoto(imagePath: '/a', videoPath: '/b'),
      isFalse,
    );
  });

  test('native permission failures reach the caller', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) => Future<Object?>.error(
        PlatformException(code: 'MOVING_PHOTO_PERMISSION'),
      ),
    );
    await expectLater(
      HarmonyChannel.saveMovingPhoto(imagePath: '/a', videoPath: '/b'),
      throwsA(
        isA<PlatformException>().having(
          (e) => e.code,
          'code',
          'MOVING_PHOTO_PERMISSION',
        ),
      ),
    );
  });
}
