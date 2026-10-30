import 'package:fpdart/fpdart.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:proalbums/core/error/failures.dart';
import 'package:proalbums/core/logging/app_logger.dart';
import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/gallery/domain/repositories/media_share_repository.dart';
import 'package:share_plus/share_plus.dart';

/// photo_manager gives us the real file of each item, share_plus opens the
/// system share sheet with those files.
final class PhotoManagerMediaShareRepository implements MediaShareRepository {
  const PhotoManagerMediaShareRepository();

  @override
  FutureResult<Unit> shareMedia(List<String> ids) async {
    try {
      final files = <XFile>[];
      for (final id in ids) {
        final asset = await AssetEntity.fromId(id);
        final file = await asset?.originFile;
        if (file != null) files.add(XFile(file.path));
      }
      if (files.isEmpty) {
        return left<Failure, Unit>(const MediaFailure('Nothing to share.'));
      }
      await SharePlus.instance.share(ShareParams(files: files));
      return right<Failure, Unit>(unit);
    } on Object catch (error, stackTrace) {
      AppLogger.e('Could not share', error: error, stackTrace: stackTrace);
      return left<Failure, Unit>(
        const MediaFailure('Could not share the selected items.'),
      );
    }
  }
}
