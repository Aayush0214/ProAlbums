import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/images/media_thumbnail_image.dart';
import 'package:proalbums/features/gallery/presentation/widgets/media_thumbnail.dart';
import 'package:proalbums/features/pdf/presentation/providers/pdf_providers.dart';

/// The picture of one PDF page: its "Crop & rotate" result when it has one,
/// else the gallery thumbnail (same cache as the grids).
class PdfPageImage extends ConsumerWidget {
  const PdfPageImage({
    required this.item,
    required this.size,
    required this.load,
    required this.fit,
    super.key,
  });

  final MediaItem item;

  /// Pixel size of the thumbnail (see thumbnailSizeFor).
  final int size;
  final ThumbnailLoader load;

  /// contain (the list: whole page) or cover (the grid: square tiles).
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final edit = ref.watch(
      pdfPageEditsProvider.select((edits) => edits[item.id]),
    );
    if (edit != null) {
      // Decoded only as big as shown (contain: the long side = size; cover:
      // the short side, so a square tile stays sharp). A new edit = a new
      // file name, so the image cache never shows an old version.
      final sizeWidth = (edit.width >= edit.height) == (fit != BoxFit.cover);
      return Image(
        image: ResizeImage(
          FileImage(File(edit.path)),
          width: sizeWidth ? size : null,
          height: sizeWidth ? null : size,
        ),
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      );
    }
    if (fit == BoxFit.cover) {
      return MediaThumbnailView(item: item, size: size, load: load);
    }
    return Image(
      image: MediaThumbnailImage(id: item.id, size: size, load: load),
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    );
  }
}
