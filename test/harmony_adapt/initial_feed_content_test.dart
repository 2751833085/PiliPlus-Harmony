import 'package:PiliPlus/harmony_adapt/widgets/initial_feed_content.dart';
import 'package:PiliPlus/harmony_adapt/widgets/harmony_loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'one near-center loader leaves before content, including retry and reduced motion',
    (tester) async {
      var loading = true;
      var reduceMotion = false;
      var ready = 0;
      var contentBuilds = 0;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(disableAnimations: reduceMotion),
                child: Scaffold(
                  body: InitialFeedContent(
                    loading: loading,
                    onReady: () => ready++,
                    builder: (_) {
                      contentBuilds++;
                      return const Text('Feed');
                    },
                  ),
                ),
              );
            },
          ),
        ),
      );
      expect(find.byType(HarmonyLoadingIndicator), findsOneWidget);
      expect(find.text('Feed'), findsNothing);
      expect(
        tester.getCenter(find.byType(HarmonyLoadingIndicator)).dy,
        inInclusiveRange(260, 300),
      );
      update(() => loading = false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.text('Feed'), findsNothing);
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.byType(HarmonyLoadingIndicator), findsNothing);
      expect(find.text('Feed'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(ready, 1);
      expect(
        contentBuilds,
        1,
        reason: 'Fading must not rebuild the feed every frame.',
      );
      update(() => loading = true);
      await tester.pump();
      expect(find.text('Feed'), findsNothing);
      update(() {
        reduceMotion = true;
        loading = false;
      });
      await tester.pumpAndSettle();
      expect(find.byType(HarmonyLoadingIndicator), findsNothing);
      expect(find.text('Feed'), findsOneWidget);
      expect(ready, 2);
      expect(tester.takeException(), isNull);
    },
  );
}
