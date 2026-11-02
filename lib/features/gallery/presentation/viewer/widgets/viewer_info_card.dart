import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/gallery/domain/entities/media_details.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/viewer/format_details.dart';
import 'package:proalbums/features/gallery/presentation/viewer/histogram.dart';
import 'package:proalbums/features/gallery/presentation/viewer/providers/details_providers.dart';

/// The Info card that floats over the picture: name, time, size, camera, a
/// small brightness graph with the shooting numbers, and where the file is.
class ViewerInfoCard extends ConsumerWidget {
  const ViewerInfoCard({required this.item, super.key});

  final MediaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(mediaDetailsProvider(item.id));

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerHigh.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: details.when(
            loading: () => _Rows(item: item, details: null),
            error: (error, stackTrace) => _Rows(item: item, details: null),
            data: (data) => _Rows(item: item, details: data),
          ),
        ),
      ),
    );
  }
}

class _Rows extends StatelessWidget {
  const _Rows({required this.item, required this.details});

  final MediaItem item;

  /// null while loading (the card shows what it already knows).
  final MediaDetails? details;

  @override
  Widget build(BuildContext context) {
    final d = details;
    final time = DateFormat('M/d/yyyy, h:mm a').format(item.createdAt);
    final width = d?.width ?? item.width;
    final height = d?.height ?? item.height;
    final size = d?.sizeBytes;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Row(label: 'Name', value: d?.name ?? '...'),
        _Row(label: 'Time', value: time),
        _Row(
          label: 'Size',
          value: [
            if (size != null) formatFileSize(size),
            if (width > 0 && height > 0) '$width × $height',
          ].join('   '),
        ),
        if (d?.camera != null) _Row(label: 'Parameters', value: d!.camera!),
        // Every picture AND video gets the graph, even without camera data (a
        // PNG has no EXIF, but it still has brightness). A video's graph is
        // made from its thumbnail frame.
        _ShootingBox(item: item, details: d),
        _Row(label: 'Path', value: d?.path ?? '...'),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(label, style: style?.copyWith(color: context.colors.textSecondary)),
          ),
          Expanded(
            child: Text(value, style: style?.copyWith(color: context.colors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

/// The darker box like the system gallery: title with the flash icon, the
/// brightness graph, then the shooting numbers spread across one line.
class _ShootingBox extends ConsumerWidget {
  const _ShootingBox({required this.item, required this.details});

  final MediaItem item;

  /// null while the details are still loading.
  final MediaDetails? details;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final histogramAsync = ref.watch(mediaHistogramProvider(item.id));
    final histogram = histogramAsync.value;
    final small = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: context.colors.textSecondary);

    final d = details;
    final numbers = <String>[
      if (d?.focalLength35mm != null) formatFocalLength(d!.focalLength35mm!),
      if (d?.aperture != null) formatAperture(d!.aperture!),
      if (d?.shutterSeconds != null) formatShutter(d!.shutterSeconds!),
      if (d?.iso != null) 'ISO ${d!.iso}',
      if (d?.exposureBias != null) formatExposureBias(d!.exposureBias!),
    ];

    // Graph could not be made and there are no numbers: show nothing.
    if (!histogramAsync.isLoading && histogram == null && numbers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (d?.focalLength35mm != null)
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '35 mm equivalent focal length',
                        style: small,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (d?.flashFired != null) ...[
                      const SizedBox(width: 6),
                      Icon(
                        d!.flashFired! ? Icons.flash_on : Icons.flash_off,
                        size: 14,
                        color: context.colors.textSecondary,
                      ),
                    ],
                  ],
                ),
              // The space is kept while the graph loads, so the card does not
              // jump when it appears.
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  height: 72,
                  width: double.infinity,
                  child: histogram == null
                      ? null
                      : CustomPaint(painter: _HistogramPainter(histogram, guideColor: context.colors.dividerSubtle)),
                ),
              ),
              if (numbers.isNotEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final text in numbers)
                      Text(text, style: small, maxLines: 1),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Smooth red / green / blue curves that ADD together (where they overlap the
/// colour turns white), with two thin guide lines at the thirds.
class _HistogramPainter extends CustomPainter {
  _HistogramPainter(this.data, {required this.guideColor});

  final HistogramData data;
  final Color guideColor;

  @override
  void paint(Canvas canvas, Size size) {
    final peak = data.peak;
    if (peak == 0) return;

    final guide = Paint()
      ..color = guideColor
      ..strokeWidth = 1;
    for (final fraction in [1 / 3, 2 / 3]) {
      final x = size.width * fraction;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), guide);
    }

    // A separate layer, so BlendMode.plus adds the three colours to each
    // other and not to the dark box behind.
    canvas.saveLayer(Offset.zero & size, Paint());
    void draw(List<int> bins, Color color) {
      final points = <Offset>[
        for (var i = 0; i < bins.length; i++)
          Offset(
            size.width * i / (bins.length - 1),
            size.height - (size.height - 2) * (bins[i] / peak),
          ),
      ];
      final path = Path()..moveTo(0, size.height);
      path.lineTo(points.first.dx, points.first.dy);
      for (var i = 0; i < points.length - 1; i++) {
        final mid = Offset(
          (points[i].dx + points[i + 1].dx) / 2,
          (points[i].dy + points[i + 1].dy) / 2,
        );
        path.quadraticBezierTo(points[i].dx, points[i].dy, mid.dx, mid.dy);
      }
      path
        ..lineTo(points.last.dx, points.last.dy)
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..blendMode = BlendMode.plus,
      );
    }

    draw(data.red, const Color(0xFFB0302A));
    draw(data.green, const Color(0xFF1FA05A));
    draw(data.blue, const Color(0xFF2A55C8));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HistogramPainter old) => old.data != data || old.guideColor != guideColor;
}
