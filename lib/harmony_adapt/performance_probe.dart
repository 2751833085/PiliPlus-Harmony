import 'dart:convert';
import 'dart:async';
import 'dart:ui' show FrameTiming, PlatformDispatcher;
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Opt-in local QA telemetry. No content, accounts, URLs or network upload.
/// The production compiler removes this branch when the flag is absent.
abstract final class HarmonyPerformanceProbe {
  static const enabled = bool.fromEnvironment('HARMONY_QA_PERFORMANCE');
  static bool _started = false;
  static final _runId = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  static int _batchId = 0;
  static Timer? _flushTimer;
  static final _build = <double>[];
  static final _raster = <double>[];
  static void start() {
    if (!enabled || _started) return;
    _started = true;
    SchedulerBinding.instance.addTimingsCallback(_record);
    // Emit short scenarios too; no timer or logging exists in ordinary builds.
    _flushTimer = Timer.periodic(const Duration(seconds: 5), (_) => _emit());
  }

  @visibleForTesting
  static void stop() {
    if (!_started) return;
    _flushTimer?.cancel();
    _flushTimer = null;
    SchedulerBinding.instance.removeTimingsCallback(_record);
    _build.clear();
    _raster.clear();
    _started = false;
  }

  static void _record(List<FrameTiming> frames) {
    for (final frame in frames) {
      _build.add(frame.buildDuration.inMicroseconds / 1000);
      _raster.add(frame.rasterDuration.inMicroseconds / 1000);
      if (_build.length == 120) _emit();
    }
  }

  static void _emit() {
    if (_build.isEmpty) return;
    final build = List<double>.of(_build);
    final raster = List<double>.of(_raster);
    _build.clear();
    _raster.clear();
    final batch = ++_batchId;
    final rate = PlatformDispatcher.instance.views.first.display.refreshRate;
    final budget = 1000 / (rate > 0 ? rate : 60);
    double percentile(List<double> values, double fraction) {
      final sorted = List<double>.of(values)..sort();
      return sorted[((sorted.length - 1) * fraction).round()];
    }

    debugPrint(
      'PiliPlusFrameTiming ${jsonEncode({
        'run_id': _runId,
        'batch_id': batch,
        'frames': build.length,
        'sample_chunks': (build.length + 19) ~/ 20,
        'reported_refresh_rate_hz': rate,
        'budget_ms': budget,
        // Rendering work is not actual presentation/FPS or a PresentFence trace.
        'build_p50_ms': percentile(build, .5),
        'build_p95_ms': percentile(build, .95),
        'raster_p50_ms': percentile(raster, .5),
        'raster_p95_ms': percentile(raster, .95),
        'raster_over_90hz_budget': raster.where((ms) => ms > 1000 / 90).length,
        'raster_over_120hz_budget': raster.where((ms) => ms > 1000 / 120).length,
        'over_budget': List.generate(build.length, (i) => i).where((i) => build[i] > budget || raster[i] > budget).length,
      })}',
    );
    for (var start = 0; start < build.length; start += 20) {
      final end = (start + 20).clamp(0, build.length);
      // At most 20 samples per line, well below hilog's line-length limit.
      debugPrint(
        'PiliPlusFrameSamples ${jsonEncode({
          'run_id': _runId,
          'batch_id': batch,
          'start': start,
          'build_ms': build.sublist(start, end),
          'raster_ms': raster.sublist(start, end),
        })}',
      );
    }
  }
}
