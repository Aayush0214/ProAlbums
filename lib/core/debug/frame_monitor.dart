import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Developer tool: prints frame statistics to the console every ~2 seconds
/// while the app is drawing. Does nothing in release builds.
///
/// READ THE NUMBERS ONLY IN PROFILE MODE (`flutter run --profile`).
/// Debug mode is deliberately slow (assertions, JIT), so its numbers are not
/// the real performance of your app.
///
/// How to read the line:
///  - "display ... Hz"  = refresh rate the OS currently gives this app
///  - "budget"          = time one frame may take (1000 / Hz)
///  - "build" / "raster"= average time of the UI thread / GPU thread per frame;
///                        BOTH must stay under the budget
///  - "slow"            = frames that missed the budget (visible jank)
abstract final class FrameMonitor {
  static bool _started = false;
  static final List<FrameTiming> _buffer = <FrameTiming>[];
  static DateTime _lastReport = DateTime.now();

  static void start() {
    if (_started || kReleaseMode) return;
    _started = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  static void _onTimings(List<FrameTiming> timings) {
    _buffer.addAll(timings);
    final now = DateTime.now();
    if (now.difference(_lastReport) < const Duration(seconds: 2)) return;
    _lastReport = now;
    _report();
    _buffer.clear();
  }

  static void _report() {
    if (_buffer.length < 2) return;

    final reportedHz = PlatformDispatcher.instance.displays.first.refreshRate;

    // Typical time between frames (median ignores idle gaps) -> real fps.
    final starts = [
      for (final t in _buffer) t.timestampInMicroseconds(FramePhase.vsyncStart),
    ];
    final intervals = <int>[
      for (var i = 1; i < starts.length; i++) starts[i] - starts[i - 1],
    ]..sort();
    final medianInterval = intervals[intervals.length ~/ 2];
    final fps = medianInterval > 0 ? 1e6 / medianInterval : 0.0;

    // Judge frames against the real rate if it is higher than what Flutter reports.
    final hz = fps > reportedHz ? fps : reportedHz;
    final budgetMs = 1000 / hz;

    var buildMicros = 0;
    var rasterMicros = 0;
    var slowFrames = 0;
    for (final timing in _buffer) {
      buildMicros += timing.buildDuration.inMicroseconds;
      rasterMicros += timing.rasterDuration.inMicroseconds;
      if (timing.totalSpan.inMicroseconds / 1000 > budgetMs) slowFrames++;
    }

    final frames = _buffer.length;
    debugPrint(
      '[frames] $frames frames | typical ${fps.toStringAsFixed(0)} fps '
          '(Flutter reports ${reportedHz.toStringAsFixed(0)} Hz) | '
          'budget ${budgetMs.toStringAsFixed(1)} ms | '
          'build ${(buildMicros / frames / 1000).toStringAsFixed(1)} ms | '
          'raster ${(rasterMicros / frames / 1000).toStringAsFixed(1)} ms | '
          'slow $slowFrames',
    );
  }
}
