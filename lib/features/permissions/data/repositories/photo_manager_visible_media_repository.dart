import 'package:photo_manager/photo_manager.dart';
import 'package:proalbums/features/permissions/domain/repositories/visible_media_repository.dart';

final class PhotoManagerVisibleMediaRepository implements VisibleMediaRepository {
  const PhotoManagerVisibleMediaRepository();

  @override
  Future<bool> hasAny() async {
    try {
      return await PhotoManager.getAssetCount(type: RequestType.common) > 0;
    } catch (_) {
      // Unknown: do NOT claim "empty", the normal screens will show it.
      return true;
    }
  }
}
