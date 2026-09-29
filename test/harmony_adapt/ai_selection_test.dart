import 'package:os_type/os_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/pages/video/ai_conclusion/view.dart';
import 'package:PiliPlus/models_new/video/video_ai_conclusion/model_result.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.ohos;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('os_type'),
          (_) async => 'phone',
        );
    await OS.initHarmonyDeviceType();
    debugDefaultTargetPlatformOverride = null;
  });
  testWidgets('AI selection and copy do not request haptics on Harmony', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.ohos;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        if (call.method == 'Clipboard.hasStrings') return {'value': false};
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => AiConclusionPanel.buildContent(
              context,
              Theme.of(context),
              AiConclusionResult(summary: '测试总结，可以选择这段内容并复制。'),
            ),
          ),
        ),
      ),
    );
    await tester.longPressAt(
      tester.getTopLeft(find.byType(SelectableText)) + const Offset(30, 10),
    );
    await tester.pumpAndSettle();
    final state = tester.state<EditableTextState>(find.byType(EditableText));
    expect(state.textEditingValue.selection.isCollapsed, isFalse);
    state.copySelection(SelectionChangedCause.toolbar);
    await tester.pumpAndSettle();
    expect(calls.any((e) => e.method == 'Clipboard.setData'), isTrue);
    expect(calls.where((e) => e.method.startsWith('HapticFeedback.')), isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });
}
