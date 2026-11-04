import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/storage/domain/entities/storage_usage.dart';
import 'package:proalbums/features/storage/domain/services/format_bytes.dart';
import 'package:proalbums/features/storage/presentation/widgets/storage_style.dart';

class StorageDonut extends StatelessWidget {
  const StorageDonut({required this.usage, this.size = 240, super.key});

  final StorageUsage usage;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Thickness of the donut ring
    final stroke = size * 0.12;

    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        // Smooth and satisfying animation curve
        duration: const Duration(milliseconds: 1200),
        curve: Curves.easeOutQuart,
        builder: (context, progress, _) => CustomPaint(
          painter: _DonutPainter(
            usage: usage,
            progress: progress,
            stroke: stroke,
            // Track background color
            track: context.colors.surfaceContainerHigh,
            colors: {
              for (final kind in StorageKind.values)
                kind: storageColorOf(kind, context),
            },
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatBytes(usage.free),
                  style: context.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 32,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Free of ${formatBytes(usage.total)}',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.usage,
    required this.progress,
    required this.stroke,
    required this.track,
    required this.colors,
  });

  final StorageUsage usage;
  final double progress;
  final double stroke;
  final Color track;
  final Map<StorageKind, Color> colors;

  // Fixed gap between arcs (in degrees, converted to radians later)
  static const double _gapDegrees = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = (size.shortestSide - stroke) / 2;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: radius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    // 1. Draw the background track (Full Circle)
    paint.color = track;
    paint.strokeCap = StrokeCap.round; // Ensure track has rounded look if not 360
    canvas.drawArc(rect, 0, math.pi * 2, false, paint);

    // 2. Draw the segments: the used kinds, then the FREE space (its own
    // colour), so the ring is the whole storage and Other and Free are never
    // mistaken for each other.
    final parts = [
      ...usage.segments,
      (kind: StorageKind.free, bytes: usage.free),
    ];
    final basis = parts.fold<int>(0, (sum, s) => sum + s.bytes);
    if (basis <= 0) return;

    // Calculate total gap space needed
    final visibleSegmentsCount = parts.where((s) => s.bytes > 0).length;

    // If only 1 segment, no gaps needed. Otherwise, calculate total gap radians.
    final totalGapRadians = visibleSegmentsCount > 1
        ? (visibleSegmentsCount * _gapDegrees * (math.pi / 180))
        : 0.0;

    // The remaining space is for the actual data arcs
    final availableRadians = (math.pi * 2) - totalGapRadians;

    // Start at Top Center (-90 degrees)
    var startAngle = -math.pi / 2;

    for (final s in parts) {
      if (s.bytes <= 0) continue;

      // Calculate how much of the available space this segment gets
      final share = s.bytes / basis;
      var sweepAngle = share * availableRadians;

      // Ensure very small values still show a tiny sliver (min 1.5 degrees),
      // but without overflowing into neighbors.
      const minSweep = 1.5 * (math.pi / 180);
      if (sweepAngle < minSweep && visibleSegmentsCount > 1) {
        sweepAngle = minSweep;
      }

      // Animate the sweep
      final animatedSweep = sweepAngle * progress;

      paint.color = colors[s.kind]!;

      // Use butt caps for all segments to prevent overlapping.
      // Round caps inherently add extra length outside the defined sweep angle.
      paint.strokeCap = StrokeCap.butt;

      // If it's the ONLY segment, we can round it nicely
      if (visibleSegmentsCount == 1) {
        paint.strokeCap = StrokeCap.round;
      }

      canvas.drawArc(
        rect,
        startAngle,
        animatedSweep,
        false,
        paint,
      );

      // Move the start angle forward by the sweep PLUS the gap for the next segment
      startAngle += sweepAngle + (_gapDegrees * (math.pi / 180));
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.progress != progress || old.usage != usage || old.track != track;
}