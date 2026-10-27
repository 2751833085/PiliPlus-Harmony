import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/pages/video/widgets/playback_request_overlay.dart';
import 'package:PiliPlus/harmony_adapt/widgets/harmony_loading.dart';

void main() {
  testWidgets(
    'loading keeps back reachable; failure replaces spinner with retry',
    (tester) async {
      var failed = false, back = 0, retried = 0;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (_, setState) {
                update = setState;
                return Stack(
                  children: [
                    const SizedBox.expand(),
                    PlaybackRequestOverlay(
                      pending: !failed,
                      failed: failed,
                      onRetry: () => retried++,
                      onBack: () => back++,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
      expect(find.byType(HarmonyLoadingIndicator), findsOneWidget);
      await tester.tap(find.byTooltip('返回'));
      expect(back, 1);
      update(() => failed = true);
      await tester.pump();
      expect(find.byType(HarmonyLoadingIndicator), findsNothing);
      await tester.tap(find.text('重试播放'));
      expect(retried, 1);
      await tester.tap(find.byTooltip('返回'));
      expect(back, 2);
      expect(tester.takeException(), isNull);
    },
  );
}
