import 'package:PiliPlus/harmony_adapt/window_layout.dart';
import 'package:PiliPlus/pages/video/reply/widgets/panel_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('auto intro expansion applies to tablet landscape, not phone or portrait', () {
    expect(HarmonyWindowLayout.autoExpandIntroduction(const Size(1107, 776)), isTrue);
    expect(HarmonyWindowLayout.autoExpandIntroduction(const Size(1024, 768)), isTrue);
    expect(HarmonyWindowLayout.autoExpandIntroduction(const Size(776, 350)), isFalse);
    expect(HarmonyWindowLayout.autoExpandIntroduction(const Size(768, 1024)), isFalse);
  });
  testWidgets('bottom comment bar has separate writing and emoji actions at all fold sizes', (tester) async {
    tester.view.devicePixelRatio = 2.875;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final width in [1008.0, 2048.0, 3184.0]) {
      tester.view.physicalSize = Size(width, 2232);
      var writing = 0, emoji = 0;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Align(alignment: Alignment.bottomCenter, child: ShortReplyComposer(onReply: () => writing++, onEmoji: () => emoji++)))));
      await tester.tap(find.text('尊重是评论打动人心的入场券'));
      expect(writing, 1);
      expect(emoji, 0);
      await tester.tap(find.byTooltip('发表情'));
      expect(writing, 1);
      expect(emoji, 1);
      expect(tester.takeException(), isNull);
    }
  });
}
