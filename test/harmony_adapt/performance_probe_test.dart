import 'dart:convert';
import 'dart:ui' show FrameTiming, PlatformDispatcher;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/harmony_adapt/performance_probe.dart';

void main() {
  testWidgets(
    'QA samples stay bounded, chunked and complete including a short tail',
    (tester) async {
      final lines = <String>[];
      final original = debugPrint;
      debugPrint = (message, {wrapWidth}) {
        if (message != null) lines.add(message);
      };
      try {
        HarmonyPerformanceProbe.start();
        PlatformDispatcher.instance.onReportTimings!(
          List.generate(
            123,
            (i) => FrameTiming(
              vsyncStart: 0,
              buildStart: 1000,
              buildFinish: 2000 + i,
              rasterStart: 3000,
              rasterFinish: 5000 + i,
              rasterFinishWallTime: 5000 + i,
              frameNumber: i,
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 5));
        final summaries = lines
            .where((x) => x.startsWith('PiliPlusFrameTiming '))
            .map(
              (x) =>
                  jsonDecode(x.substring('PiliPlusFrameTiming '.length)) as Map,
            )
            .toList();
        final chunks = lines
            .where((x) => x.startsWith('PiliPlusFrameSamples '))
            .map(
              (x) =>
                  jsonDecode(x.substring('PiliPlusFrameSamples '.length))
                      as Map,
            )
            .toList();
        expect(summaries.map((x) => x['frames']), [120, 3]);
        expect(chunks.length, 7);
        expect(
          chunks.every((x) => (x['build_ms'] as List).length <= 20),
          isTrue,
        );
        expect(
          chunks.fold<int>(0, (n, x) => n + (x['build_ms'] as List).length),
          123,
        );
        expect(lines.every((x) => utf8.encode(x).length < 850), isTrue);
      } finally {
        HarmonyPerformanceProbe.stop();
        debugPrint = original;
      }
    },
    // Explicit diagnostic test: enable HARMONY_QA_PERFORMANCE at compile time.
    skip: !HarmonyPerformanceProbe.enabled,
  );
}
