import 'package:flutter/foundation.dart';
import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:PiliPlus/harmony_adapt/harmony_channel.dart';
import 'package:PiliPlus/harmony_adapt/widgets/harmony_navigation_surface.dart';
import 'package:PiliPlus/harmony_adapt/widgets/native_navigation_spacer.dart';
import 'package:PiliPlus/harmony_adapt/widgets/navigation_press_feedback.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('fallback never creates a duplicate Flutter blur, retains taps', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      for (final immersive in [true, false]) {
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: HarmonyTheme.apply(
              ThemeData(brightness: brightness),
              immersive: immersive,
            ),
            home: Scaffold(
              bottomNavigationBar: HarmonyNavigationSurface(
                child: NavigationPressFeedback(
                  child: TextButton(
                    onPressed: () => taps++,
                    child: const Text('首页'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(BackdropFilter), findsNothing);
        final fill = tester.widget<ColoredBox>(
          find.descendant(
            of: find.byType(HarmonyNavigationSurface),
            matching: find.byType(ColoredBox),
          ),
        );
        expect(
          fill.color,
          brightness == Brightness.dark
              ? const Color(0xFF25262A)
              : const Color(0xFFF7F8FA),
        );
        await tester.tap(find.text('首页'));
        await tester.pumpAndSettle();
        expect(taps, 1);
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets(
    'native bar reserves safe area across widths, scaling and route coverage',
    (tester) async {
      final oldExtent = HarmonyChannel.nativeNavigationExtent.value;
      final oldVisible = HarmonyChannel.nativeDockInset.value;
      addTearDown(() {
        HarmonyChannel.nativeNavigationExtent.value = oldExtent;
        HarmonyChannel.nativeDockInset.value = oldVisible;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      tester.view.devicePixelRatio = 2.875;
      for (final width in [390.0, 740.0, 1108.0]) {
        tester.view.physicalSize = Size(width, 800) * 2.875;
        for (final scale in [1.0, 1.25]) {
          HarmonyChannel.nativeNavigationExtent.value = 0;
          double? padding;
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                extendBody: true,
                body: Builder(
                  builder: (context) {
                    padding = MediaQuery.paddingOf(context).bottom;
                    return const SizedBox.expand();
                  },
                ),
                bottomNavigationBar: NativeNavigationSpacer(
                  extent: HarmonyChannel.nativeNavigationExtent,
                  scale: scale,
                  fallback: 52 / scale,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(padding, 52 / scale);
          await HarmonyChannel.handler(
            const MethodCall('onDockMetrics', {
              'bottom': 76,
              'layoutExtent': 76,
            }),
          );
          await tester.pumpAndSettle();
          expect(padding, 76 / scale);
          expect(
            tester.getSize(find.byType(NativeNavigationSpacer)),
            Size(width, 76 / scale),
          );
          await HarmonyChannel.handler(
            const MethodCall('onDockMetrics', {
              'bottom': 0,
              'layoutExtent': 76,
            }),
          );
          await tester.pumpAndSettle();
          expect(HarmonyChannel.nativeDockInset.value, 0);
          expect(
            padding,
            76 / scale,
            reason: 'route/modal coverage must not resize the underlying feed',
          );
          expect(find.byType(BackdropFilter), findsNothing);
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  testWidgets(
    'native navigation intercepts duplicate physical touches over video cards',
    (tester) async {
      tester.view.devicePixelRatio = 2.875;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        HarmonyChannel.onShellTabSwitch = null;
      });
      for (final width in [390.0, 740.0, 1108.0]) {
        tester.view.physicalSize = Size(width, 800) * 2.875;
        final extent = ValueNotifier<double>(76);
        var openedVideo = 0;
        var dragStarts = 0;
        final selectedTabs = <int>[];
        HarmonyChannel.onShellTabSwitch = selectedTabs.add;
        await HarmonyChannel.setShellBarsObscured(false);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              extendBody: true,
              body: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => openedVideo++,
                onVerticalDragStart: (_) => dragStarts++,
                child: const SizedBox.expand(),
              ),
              bottomNavigationBar: NativeNavigationSpacer(
                extent: extent,
                scale: 1,
                fallback: 76,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        // ArkUI dispatches a navigation event while Flutter may receive the
        // same pointer. Only navigation must run, including empty side margins.
        for (final x in [5.0, width / 3, width * 2 / 3, width - 5]) {
          await HarmonyChannel.handler(
            const MethodCall('showTab', {'index': 1}),
          );
          await tester.tapAt(Offset(x, 750));
          await tester.pump();
          await tester.tapAt(Offset(x, 790)); // system-safe strip
          await tester.pump();
        }
        await tester.dragFrom(Offset(width / 2, 750), const Offset(0, -100));
        await tester.pumpAndSettle();
        expect(openedVideo, 0);
        expect(dragStarts, 0);
        expect(selectedTabs, [1, 1, 1, 1]);
        await tester.tapAt(Offset(width / 2, 600));
        await tester.pump();
        expect(
          openedVideo,
          1,
          reason: 'the feed above the bar stays interactive',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        extent.dispose();
      }
    },
  );

  testWidgets(
    'native tabs keep repeated home taps and reject taps behind dialogs',
    (tester) async {
      final calls = <int>[];
      HarmonyChannel.onShellTabSwitch = calls.add;
      addTearDown(() async {
        HarmonyChannel.onShellTabSwitch = null;
        await HarmonyChannel.setShellBarsObscured(false);
      });
      await HarmonyChannel.setShellBarsObscured(false);
      await HarmonyChannel.handler(const MethodCall('showTab', {'index': 0}));
      await HarmonyChannel.handler(const MethodCall('showTab', {'index': 0}));
      await HarmonyChannel.handler(const MethodCall('showTab', {'index': 2}));
      expect(calls, [0, 0, 2]);
      await HarmonyChannel.setShellBarsObscured(true);
      await HarmonyChannel.handler(const MethodCall('showTab', {'index': 1}));
      expect(calls, [0, 0, 2]);
    },
  );
}
