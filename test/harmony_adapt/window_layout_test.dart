// Relative imports also let tool/check_harmony_layout.sh run without app plugins.
// ignore_for_file: avoid_relative_lib_imports

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/common/widgets/adaptive_navigation_body.dart';
import '../../lib/harmony_adapt/window_layout.dart';

void main() {
  test('navigation follows window width including the breakpoint', () {
    for (final width in [320.0, 420.0, 599.0]) {
      expect(HarmonyWindowLayout.useBottomNavigation(width), isTrue);
    }
    for (final width in [600.0, 800.0, 1200.0]) {
      expect(HarmonyWindowLayout.useBottomNavigation(width), isFalse);
    }
  });

  testWidgets('folding and split screen keep content state and scroll offset', (
    tester,
  ) async {
    _ContentProbeState? initialState;
    // Synthetic logical window sizes, not claimed Mate XTS measurements.
    for (final width in [420.0, 700.0, 1100.0, 800.0, 350.0, 420.0]) {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: width,
              height: 500,
              child: AdaptiveNavigationBody(
                navigation: HarmonyWindowLayout.useBottomNavigation(width)
                    ? null
                    : const SizedBox(width: 80),
                divider: const SizedBox(width: 1),
                child: const _ContentProbe(),
              ),
            ),
          ),
        ),
      );
      final state = tester.state<_ContentProbeState>(
        find.byType(_ContentProbe),
      );
      if (initialState == null) {
        initialState = state;
        state.scroll.jumpTo(200);
      }
      expect(identical(state, initialState), isTrue);
      expect(state.scroll.offset, 200);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    expect(initialState!.disposed, isTrue);
  });
}

class _ContentProbe extends StatefulWidget {
  const _ContentProbe();

  @override
  State<_ContentProbe> createState() => _ContentProbeState();
}

class _ContentProbeState extends State<_ContentProbe> {
  final scroll = ScrollController();
  bool disposed = false;

  @override
  Widget build(BuildContext context) => ListView.builder(
    controller: scroll,
    itemCount: 100,
    itemExtent: 40,
    itemBuilder: (_, index) => Text('Video $index'),
  );

  @override
  void dispose() {
    disposed = true;
    scroll.dispose();
    super.dispose();
  }
}
