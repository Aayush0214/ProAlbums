import 'package:photo_manager/photo_manager.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';

/// AssetEntity (plugin) -> MediaItem (domain).
abstract final class MediaItemMapper {
  static MediaItem fromAsset(AssetEntity asset) {
    final isVideo = asset.type == AssetType.video;
    return MediaItem(
      id: asset.id,
      type: isVideo ? MediaType.video : MediaType.image,
      createdAt: asset.createDateTime,
      width: asset.width,
      height: asset.height,
      duration: isVideo ? asset.videoDuration : Duration.zero,
      isFavorite: asset.isFavorite,
    );
  }
}
