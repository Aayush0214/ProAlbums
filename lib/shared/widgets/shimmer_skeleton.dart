import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:proalbums/core/theme/app_colors.dart';

/// Lays out the grey boxes of a skeleton inside [size].
typedef SkeletonLayout = List<RRect> Function(Size size);

/// Grey placeholder boxes with a soft light sweeping across them, shown
/// while something loads (instead of a spinner).
///
/// Cheap on purpose: ONE CustomPainter draws every box with one gradient
/// (no ShaderMask / Opacity, which would need an extra offscreen layer every
/// frame). Every skeleton on screen takes its phase from the same clock, so
/// they shine together.
class ShimmerSkeleton extends StatefulWidget {
  const ShimmerSkeleton({required this.layout, this.height, super.key});

  final SkeletonLayout layout;

  /// Fixed height; null = as tall as the parent allows.
  final double? height;

  @override
  State<ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<ShimmerSkeleton>
    with SingleTickerProviderStateMixin {
  /// Only repaints the painter; the phase comes from the frame clock.
  late final AnimationController _ticker = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = context.colors.surfaceContainerHigh;
    final highlight = Color.lerp(base, context.colorScheme.onSurface, 0.08)!;
    final painter = CustomPaint(
      painter: _SkeletonPainter(
        repaint: _ticker,
        layout: widget.layout,
        base: base,
        highlight: highlight,
      ),
    );
    return RepaintBoundary(
      child: widget.height == null
          ? SizedBox.expand(child: painter)
          : SizedBox(height: widget.height, width: double.infinity, child: painter),
    );
  }
}

class _SkeletonPainter extends CustomPainter {
  _SkeletonPainter({
    required Listenable repaint,
    required this.layout,
    required this.base,
    required this.highlight,
  }) : super(repaint: repaint);

  final SkeletonLayout layout;
  final Color base;
  final Color highlight;

  /// One sweep across the screen.
  static const int _periodMs = 1400;

  @override
  void paint(Canvas canvas, Size size) {
    final now = SchedulerBinding.instance.currentFrameTimeStamp.inMilliseconds;
    final phase = (now % _periodMs) / _periodMs; // 0..1, same for everyone
    // A light band 40% of the width wide, moving left to right (it starts
    // and ends outside, so the boxes rest on their base colour between).
    final bandWidth = size.width * 0.4;
    final x = -bandWidth + phase * (size.width + 2 * bandWidth);
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [base, highlight, base],
        stops: const [0, 0.5, 1],
      ).createShader(Rect.fromLTWH(x, 0, bandWidth, size.height))
      ..color = base;
    // Outside the band the gradient is clamped to [base]: one paint for all.
    for (final box in layout(size)) {
      canvas.drawRRect(box, paint);
    }
  }

  @override
  bool shouldRepaint(_SkeletonPainter oldDelegate) =>
      oldDelegate.base != base ||
      oldDelegate.highlight != highlight ||
      oldDelegate.layout != layout;
}
