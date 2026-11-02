import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:proalbums/core/error/failures.dart';
import 'package:proalbums/core/logging/app_logger.dart';
import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/gallery/domain/repositories/media_image_repository.dart';

/// photo_manager decodes the original and scales it down while decoding, so a
/// 12 MB photo never becomes a 48 MB bitmap in memory.
final class PhotoManagerMediaImageRepository implements MediaImageRepository {
  const PhotoManagerMediaImageRepository();

  @override
  FutureResult<Uint8List?> loadDisplayImage({
    required String id,
    required int maxLongEdge,
  }) async {
    try {
      final asset = await AssetEntity.fromId(id);
      if (asset == null) return right<Failure, Uint8List?>(null);

      final bytes = await asset.thumbnailDataWithSize(
        displaySizeFor(
          width: asset.orientatedWidth,
          height: asset.orientatedHeight,
          maxLongEdge: maxLongEdge,
        ),
        quality: 90,
      );
      return right<Failure, Uint8List?>(bytes);
    } on Object catch (error, stackTrace) {
      AppLogger.e('Could not load the photo', error: error, stackTrace: stackTrace);
      return left<Failure, Uint8List?>(
        const MediaFailure('Could not load this photo.'),
      );
    }
  }
}

/// Same shape as the photo (so nothing is cropped), longer side at most
/// [maxLongEdge], never bigger than the original.
ThumbnailSize displaySizeFor({
  required int width,
  required int height,
  required int maxLongEdge,
}) {
  // Unknown size (some items have none): ask for a square, the plugin keeps
  // the picture's own shape inside it.
  if (width <= 0 || height <= 0) return ThumbnailSize.square(maxLongEdge);

  final longEdge = math.max(width, height);
  final scale = longEdge > maxLongEdge ? maxLongEdge / longEdge : 1.0;
  return ThumbnailSize(
    math.max(1, (width * scale).round()),
    math.max(1, (height * scale).round()),
  );
}
