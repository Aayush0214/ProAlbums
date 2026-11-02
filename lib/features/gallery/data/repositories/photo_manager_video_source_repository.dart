import 'dart:io' show Platform;

import 'package:fpdart/fpdart.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:proalbums/core/error/failures.dart';
import 'package:proalbums/core/logging/app_logger.dart';
import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/gallery/domain/repositories/video_source_repository.dart';

/// Gets the video file through photo_manager (MediaStore on Android).
final class PhotoManagerVideoSourceRepository implements VideoSourceRepository {
  const PhotoManagerVideoSourceRepository();

  @override
  FutureResult<String?> resolvePath(String id) async {
    // Android: a video is always at this address (the id from photo_manager IS
    // the MediaStore id). The player can open it directly, so there is no
    // platform call and no file lookup before playing.
    if (Platform.isAndroid) {
      return right<Failure, String?>('content://media/external/video/media/$id');
    }
    try {
      final asset = await AssetEntity.fromId(id);
      if (asset == null) return right<Failure, String?>(null);
      final file = await asset.file;
      return right<Failure, String?>(file?.path);
    } on Object catch (error, stackTrace) {
      AppLogger.e('Could not open the video', error: error, stackTrace: stackTrace);
      return left<Failure, String?>(
        const MediaFailure('Could not open this video.'),
      );
    }
  }
}
