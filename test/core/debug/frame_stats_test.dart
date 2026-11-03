import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/core/debug/frame_monitor.dart';

/// [n] frames 8333 µs apart (120 Hz).
List<int> _vsync120(int n) => [for (var i = 0; i < n; i++) i * 8333];

void main() {
  test('too few frames: nothing to say', () {
    expect(
      FrameStats.fromDurations(
        builds: [1000],
        rasters: [1000],
        vsyncStarts: [0],
        reportedHz: 120,
      ),
      isNull,
    );
  });

  test('cost is max(build, raster); jank counts frames over budget', () {
    final stats = FrameStats.fromDurations(
      builds: [2000, 9000, 1000, 1000],
      rasters: [3000, 1000, 12000, 2000],
      vsyncStarts: _vsync120(4),
      reportedHz: 120,
    )!;
    expect(stats.jank, 2); // 9 ms (build) and 12 ms (raster) > 8.3 ms
    expect(stats.maxMs, 12);
    expect(stats.worstIsRaster, isTrue);
    expect(stats.avgBuildMs, closeTo(3.25, 1e-9));
    expect(stats.avgRasterMs, closeTo(4.5, 1e-9));
  });

  test('enough frames: a measured 120 Hz beats a reported 60 Hz', () {
    final stats = FrameStats.fromDurations(
      builds: List.filled(40, 1000),
      rasters: List.filled(40, 1000),
      vsyncStarts: _vsync120(40),
      reportedHz: 60,
    )!;
    expect(stats.hz, closeTo(120, 0.1));
  });

  test('a few frames: their noisy rate never sets the budget', () {
    final stats = FrameStats.fromDurations(
      builds: [1000, 1000],
      rasters: [1000, 1000],
      vsyncStarts: [0, 7900], // looks like 126 Hz
      reportedHz: 120,
    )!;
    expect(stats.hz, 120);
  });

  test('percentiles come from the sorted costs', () {
    final costs = [for (var i = 1; i <= 100; i++) i * 100]; // 0.1 … 10 ms
    final stats = FrameStats.fromDurations(
      builds: costs,
      rasters: List.filled(100, 0),
      vsyncStarts: _vsync120(100),
      reportedHz: 120,
    )!;
    expect(stats.p90Ms, closeTo(9.0, 1e-9));
    expect(stats.p99Ms, closeTo(9.9, 1e-9));
    expect(stats.maxMs, closeTo(10.0, 1e-9));
    expect(stats.worstIsRaster, isFalse);
  });

  test('drawing at 60 fps on a 120 Hz screen is judged at 120 Hz', () {
    final stats = FrameStats.fromDurations(
      builds: [9000, 9000, 9000],
      rasters: [1000, 1000, 1000],
      vsyncStarts: [0, 16666, 33333], // one frame every 2 refreshes
      reportedHz: 120, // what the screen can do (FrameMonitor's peak)
    )!;
    expect(stats.measuredFps, closeTo(60, 0.1));
    expect(stats.hz, 120);
    expect(stats.jank, 3);
    expect(stats.describe(totalJankPercent: 0), contains('60 fps @ 120 Hz'));
  });

  test('the line marks debug numbers', () {
    final stats = FrameStats.fromDurations(
      builds: [1000, 1000],
      rasters: [1000, 1000],
      vsyncStarts: _vsync120(2),
      reportedHz: 120,
    )!;
    expect(stats.describe(totalJankPercent: 0), isNot(contains('DEBUG')));
    expect(stats.describe(totalJankPercent: 0, debug: true), contains('DEBUG'));
  });
}
