import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/compress/domain/compress_repository.dart';
import 'package:proalbums/features/compress/domain/compress_rules.dart';

/// What the person chose in the picture sheet.
typedef ImageCompressChoice = ({double scale, int quality});

/// "Compress size" for a picture (like the system gallery): the size of the
/// copy ("About 2.74 MB", follows the sliders), Resolution 20–100 % with the
/// W × H it gives, Image quality Lowest … Highest, then Compress.
Future<ImageCompressChoice?> showImageCompressSheet(
  BuildContext context, {
  required String id,
  required MediaCompressInfo info,
  required CompressRepository repository,
}) async {
  final choice = await showModalBottomSheet<ImageCompressChoice>(
    context: context,
    isScrollControlled: true,
    builder: (context) =>
        _ImageCompressSheet(id: id, info: info, repository: repository),
  );
  // The picture kept for the estimates is not needed any more.
  unawaited(repository.forgetImage());
  return choice;
}

class _ImageCompressSheet extends StatefulWidget {
  const _ImageCompressSheet({
    required this.id,
    required this.info,
    required this.repository,
  });

  final String id;
  final MediaCompressInfo info;
  final CompressRepository repository;

  @override
  State<_ImageCompressSheet> createState() => _ImageCompressSheetState();
}

class _ImageCompressSheetState extends State<_ImageCompressSheet> {
  int _scaleIndex = imageScales.length - 1;
  double _quality = 1;
  int? _estimate;

  /// The sliders move many times a second; one estimate after they rest.
  Timer? _wait;
  int _asked = 0;

  double get _scale => imageScales[_scaleIndex];

  @override
  void initState() {
    super.initState();
    unawaited(_estimateNow());
  }

  @override
  void dispose() {
    _wait?.cancel();
    super.dispose();
  }

  void _changed() {
    _wait?.cancel();
    _wait = Timer(const Duration(milliseconds: 200), _estimateNow);
  }

  Future<void> _estimateNow() async {
    final ask = ++_asked;
    final bytes = await widget.repository.estimateImage(
      widget.id,
      scale: _scale,
      quality: jpegQualityFor(_quality),
    );
    // An older answer that came late is thrown away.
    if (!mounted || ask != _asked) return;
    setState(() => _estimate = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final secondary = context.colors.textSecondary;
    final width = (widget.info.width * _scale).round();
    final height = (widget.info.height * _scale).round();
    final labelStyle = context.textTheme.bodySmall?.copyWith(color: secondary);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const SizedBox(width: 36),
                Expanded(
                  child: Text(
                    'Compress size',
                    textAlign: TextAlign.center,
                    style: context.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(LucideIcons.x),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                children: [
                  Text('Image size', style: context.textTheme.titleMedium),
                  const Spacer(),
                  Text(
                    _estimate == null
                        ? 'Calculating…'
                        : 'About ${formatMegabytes(_estimate!)}',
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: secondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                children: [
                  Text('Resolution', style: context.textTheme.titleMedium),
                  const Spacer(),
                  Text(
                    '$width × $height',
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: secondary,
                    ),
                  ),
                ],
              ),
            ),
            Slider(
              value: _scaleIndex.toDouble(),
              max: (imageScales.length - 1).toDouble(),
              divisions: imageScales.length - 1,
              onChanged: (value) {
                setState(() => _scaleIndex = value.round());
                _changed();
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final scale in imageScales)
                    Text('${(scale * 100).round()}%', style: labelStyle),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Image quality', style: context.textTheme.titleMedium),
            Slider(
              value: _quality,
              onChanged: (value) {
                setState(() => _quality = value);
                _changed();
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Lowest', style: labelStyle),
                  Text('Highest', style: labelStyle),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context)
                    .pop((scale: _scale, quality: jpegQualityFor(_quality))),
                child: const Text('Compress'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
