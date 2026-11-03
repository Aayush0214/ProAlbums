import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Developer tool: prints frame statistics to the console while the app is
/// drawing. Does nothing in release builds.
///
/// READ THE NUMBERS ONLY IN PROFILE MODE (`flutter run --profile`).
/// Debug mode is deliberately slow (assertions, JIT); its lines are marked
/// "DEBUG" so they are never mistaken for real numbers.
///
/// One line per burst of drawing: when the screen stops changing for a
/// moment (a scroll ended), or every 2 seconds during a long one.
///
///   [frames] 238 f | 120 Hz budget 8.3 ms | build 2.1 / raster 3.4 avg |
///   cost p90 5.0 p99 9.1 max 14.2 ms (raster) | jank 3 (1.3%) | total 0.9%
///
///  - cost  = max(build, raster) of one frame: the UI thread and the raster
///            thread work in parallel, so the slower one decides whether
///            the frame is on time. This is the honest per-frame number.
///  - p90 / p99 / max = 90% / 99% / all frames took at most this long.
///            Averages hide jank; the tail (p99, max) is what you see.
///  - (build) / (raster) after max = which thread made the worst frame:
///            build → our Dart code (widgets, layout); raster → painting
///            (images, clips, shaders, saveLayer).
///  - jank  = frames whose cost was over the budget (missed a refresh).
///  - total = jank % since the app started (or since [reset]).
abstract final class FrameMonitor {
  static bool _started = false;
  static final List<FrameTiming> _buffer = <FrameTiming>[];
  static DateTime _windowStart = DateTime.now();
  static Timer? _idle;

  static int _totalFrames = 0;
  static int _totalJank = 0;

  /// The fastest rate seen so far = what the screen can do (120 Hz). Used as
  /// the budget even when the app itself only manages 60 fps (otherwise a
  /// steady 60 fps would be judged against a 60 Hz budget and look perfect).
  static double _peakHz = 0;

  /// A burst ends when no frame came for this long.
  static const Duration _idleGap = Duration(milliseconds: 600);

  /// A long burst is still reported in pieces of this length.
  static const Duration _maxWindow = Duration(seconds: 2);

  static void start() {
    if (_started || kReleaseMode) return;
    _started = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  /// Starts the "total" from zero (e.g. before a measured run).
  static void reset() {
    _totalFrames = 0;
    _totalJank = 0;
    debugPrint('[frames] reset');
    developer.postEvent('proalbums.frames', {'line': '[frames] reset'});
  }

  static void _onTimings(List<FrameTiming> timings) {
    if (_buffer.isEmpty) _windowStart = DateTime.now();
    _buffer.addAll(timings);
    _idle?.cancel();
    if (DateTime.now().difference(_windowStart) >= _maxWindow) {
      _flush();
    } else {
      _idle = Timer(_idleGap, _flush);
    }
  }

  static void _flush() {
    _idle?.cancel();
    _idle = null;
    final frames = List<FrameTiming>.of(_buffer);
    _buffer.clear();
    final stats = FrameStats.of(
      frames,
      reportedHz: math.max(
        PlatformDispatcher.instance.displays.first.refreshRate,
        _peakHz,
      ),
    );
    if (stats == null) return;
    // Only a burst with enough frames says what the screen can do.
    if (stats.frames >= FrameStats._minFramesForRate) {
      _peakHz = math.max(_peakHz, stats.measuredFps);
    }
    _totalFrames += stats.frames;
    _totalJank += stats.jank;
    final line = stats.describe(
      totalJankPercent: _totalJank * 100 / _totalFrames,
      debug: kDebugMode,
    );
    debugPrint(line);
    // Also over the VM service, for phones that hide app logs from logcat
    // (some Vivo / iQOO builds): a tool connected to the VM service can
    // listen to the "Extension" stream for this event.
    developer.postEvent('proalbums.frames', {'line': line});
  }
}

/// The numbers of one burst of frames (pure, so it can be tested).
@immutable
final class FrameStats {
  const FrameStats({
    required this.frames,
    required this.hz,
    required this.measuredFps,
    required this.avgBuildMs,
    required this.avgRasterMs,
    required this.p90Ms,
    required this.p99Ms,
    required this.maxMs,
    required this.worstIsRaster,
    required this.jank,
  });

  /// Fewer frames than this: the measured rate is too noisy to trust.
  static const int _minFramesForRate = 30;

  /// null when there are too few frames to say anything.
  static FrameStats? of(List<FrameTiming> timings, {required double reportedHz}) {
    if (timings.length < 2) return null;
    return fromDurations(
      builds: [for (final t in timings) t.buildDuration.inMicroseconds],
      rasters: [for (final t in timings) t.rasterDuration.inMicroseconds],
      vsyncStarts: [
        for (final t in timings) t.timestampInMicroseconds(FramePhase.vsyncStart),
      ],
      reportedHz: reportedHz,
    );
  }

  /// Same, from plain microsecond lists (one entry per frame).
  static FrameStats? fromDurations({
    required List<int> builds,
    required List<int> rasters,
    required List<int> vsyncStarts,
    required double reportedHz,
  }) {
    final n = builds.length;
    if (n < 2 || rasters.length != n || vsyncStarts.length != n) return null;

    // Typical time between frames (the median ignores idle gaps) → the rate
    // the phone really runs at. Flutter sometimes reports 60 Hz on a 120 Hz
    // screen, so the higher of the two decides the budget.
    final intervals = <int>[
      for (var i = 1; i < n; i++) vsyncStarts[i] - vsyncStarts[i - 1],
    ]..sort();
    final median = intervals[intervals.length ~/ 2];
    final measuredHz = median > 0 ? 1e6 / median : 0.0;
    // A handful of frames gives a noisy rate (e.g. "126 Hz"): then only the
    // reported / known screen rate sets the budget.
    final hz = n >= _minFramesForRate
        ? math.max(measuredHz, reportedHz)
        : reportedHz;
    final budgetMicros = 1e6 / hz;

    var buildSum = 0;
    var rasterSum = 0;
    var jank = 0;
    var worst = -1;
    var worstIsRaster = false;
    final costs = <int>[];
    for (var i = 0; i < n; i++) {
      buildSum += builds[i];
      rasterSum += rasters[i];
      final cost = math.max(builds[i], rasters[i]);
      costs.add(cost);
      if (cost > budgetMicros) jank++;
      if (cost > worst) {
        worst = cost;
        worstIsRaster = rasters[i] >= builds[i];
      }
    }
    costs.sort();
    double percentile(double q) =>
        costs[math.min(n - 1, math.max(0, (q * n).ceil() - 1))] / 1000;

    return FrameStats(
      frames: n,
      hz: hz,
      measuredFps: measuredHz,
      avgBuildMs: buildSum / n / 1000,
      avgRasterMs: rasterSum / n / 1000,
      p90Ms: percentile(0.90),
      p99Ms: percentile(0.99),
      maxMs: worst / 1000,
      worstIsRaster: worstIsRaster,
      jank: jank,
    );
  }

  final int frames;

  /// The screen rate the frames are judged against (the budget).
  final double hz;

  /// The rate the app really drew at (from the typical gap between frames).
  final double measuredFps;
  final double avgBuildMs;
  final double avgRasterMs;
  final double p90Ms;
  final double p99Ms;
  final double maxMs;
  final bool worstIsRaster;
  final int jank;

  double get budgetMs => 1000 / hz;
  double get jankPercent => jank * 100 / frames;

  String describe({required double totalJankPercent, bool debug = false}) {
    String ms(double v) => v.toStringAsFixed(1);
    return '[frames]${debug ? ' DEBUG (not real numbers)' : ''} '
        '$frames f | ${measuredFps.toStringAsFixed(0)} fps @ '
        '${hz.toStringAsFixed(0)} Hz budget ${ms(budgetMs)} ms | '
        'build ${ms(avgBuildMs)} / raster ${ms(avgRasterMs)} avg | '
        'cost p90 ${ms(p90Ms)} p99 ${ms(p99Ms)} max ${ms(maxMs)} ms '
        '(${worstIsRaster ? 'raster' : 'build'}) | '
        'jank $jank (${jankPercent.toStringAsFixed(1)}%) | '
        'total ${totalJankPercent.toStringAsFixed(1)}%';
  }
}
