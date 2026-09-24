import 'dart:convert';
import 'dart:ui' show FrameTiming, PlatformDispatcher;
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Opt-in local QA telemetry. No content, accounts, URLs or network upload.
/// The production compiler removes this branch when the flag is absent.
abstract final class HarmonyPerformanceProbe {
  static const enabled = bool.fromEnvironment('HARMONY_QA_PERFORMANCE');
  static bool _started = false;
  static final _build = <double>[];
  static final _raster = <double>[];
  static void start() {
    if (!enabled || _started) return;
    _started = true;
    SchedulerBinding.instance.addTimingsCallback(_record);
  }

  static void _record(List<FrameTiming> frames) {
    for (final frame in frames) {
      _build.add(frame.buildDuration.inMicroseconds / 1000);
      _raster.add(frame.rasterDuration.inMicroseconds / 1000);
      if (_build.length == 120) {
        final rate =
            PlatformDispatcher.instance.views.first.display.refreshRate;
        final budget = 1000 / (rate > 0 ? rate : 60);
        double percentile(List<double> values, double fraction) {
          final sorted = List<double>.of(values)..sort();
          return sorted[((sorted.length - 1) * fraction).round()];
        }

        debugPrint(
          'PiliPlusFrameTiming ${jsonEncode({
            'frames': _build.length,
            'budget_ms': budget,
            'build_p50_ms': percentile(_build, .5),
            'build_p95_ms': percentile(_build, .95),
            'raster_p50_ms': percentile(_raster, .5),
            'raster_p95_ms': percentile(_raster, .95),
            'over_budget': List.generate(_build.length, (i) => i).where((i) => _build[i] > budget || _raster[i] > budget).length,
          })}',
        );
        _build.clear();
        _raster.clear();
      }
    }
  }
}
