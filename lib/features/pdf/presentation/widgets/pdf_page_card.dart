import 'package:flutter/material.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/images/media_thumbnail_image.dart';
import 'package:proalbums/features/pdf/presentation/widgets/pdf_page_image.dart';

/// One page of the PDF in the Convert PDF list (look only): the whole
/// picture (never cropped, edited if it was) on a card, with its page number
/// ("2/19") under it.
class PdfPageCard extends StatelessWidget {
  const PdfPageCard({
    required this.item,
    required this.number,
    required this.total,
    required this.load,
    super.key,
  });

  /// Card height (fixed, so the list never jumps while pictures load).
  static const double height = 220;

  /// The biggest shared thumbnail size: sharp enough for a card, and
  /// already in the image cache when the grid used it.
  static const int _thumbnailSize = 512;

  final MediaItem item;
  final int number;
  final int total;
  final ThumbnailLoader load;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ColoredBox(
        // Dark: near black, like the system gallery. Light: a tinted grey,
        // so white pages and the white background do not blend.
        color: context.isDarkMode
            ? context.colors.canvasPure
            : context.colors.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            children: [
              Expanded(
                child: PdfPageImage(
                  item: item,
                  size: _thumbnailSize,
                  load: load,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 10),
              Text('$number/$total', style: context.textTheme.titleMedium),
            ],
          ),
        ),
      ),
    );
  }
}
