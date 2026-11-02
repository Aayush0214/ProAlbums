import 'package:photo_manager/photo_manager.dart';
import 'package:proalbums/core/logging/app_logger.dart';

/// One album as photo_manager reports it.
typedef AlbumData = ({
  String id,
  String name,
  bool isAll,
  int count,
  AssetEntity? cover,
});

/// Albums = the folders of MediaStore (Android) / PhotoKit (iOS).
final class PhotoManagerAlbumDataSource {
  PhotoManagerAlbumDataSource({required this._remember});

  /// Hands loaded assets to the thumbnail loader (fast system thumbnails).
  final void Function(List<AssetEntity>) _remember;

  // Same filters as the Photos tab, so the counts are the same.
  static const FilterOption _imageOption = FilterOption(
    sizeConstraint: SizeConstraint(ignoreSize: true),
  );
  static const FilterOption _videoOption = FilterOption(
    sizeConstraint: SizeConstraint(ignoreSize: true),
    durationConstraint: DurationConstraint(allowNullable: true),
  );

  FilterOptionGroup _filter() => FilterOptionGroup(
        imageOption: _imageOption,
        videoOption: _videoOption,
        orders: [const OrderOption(type: OrderOptionType.createDate)],
      );

  Future<List<AlbumData>> loadAlbums({
    required String allId,
    required String videosId,
  }) async {
    final folders = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      filterOption: _filter(),
    );
    final videos = await PhotoManager.getAssetPathList(
      onlyAll: true,
      type: RequestType.video,
      filterOption: _filter(),
    );

    final result = await Future.wait([
      for (final path in folders)
        _describe(path, id: path.isAll ? allId : path.id, isAll: path.isAll),
      for (final path in videos)
        _describe(path, id: videosId, name: 'Videos', isAll: false),
    ]);
    return [
      for (final album in result)
        if (album.count > 0) album,
    ];
  }

  Future<AlbumData> _describe(
    AssetPathEntity path, {
    required String id,
    required bool isAll,
    String? name,
  }) async {
    final count = await path.assetCountAsync;
    final covers = count == 0
        ? const <AssetEntity>[]
        : await path.getAssetListRange(start: 0, end: 1);
    _remember(covers);
    // Debug aid: the real folder of each album (from its newest item).
    AppLogger.d(
      '[albums] ${name ?? path.name} id=$id count=$count '
      'folder=${covers.isEmpty ? '-' : covers.first.relativePath}',
    );
    return (
      id: id,
      name: name ?? (path.isAll ? 'All' : path.name),
      isAll: isAll,
      count: count,
      cover: covers.isEmpty ? null : covers.first,
    );
  }

  /// One picture / video by id (null when it does not exist any more).
  Future<AssetEntity?> loadAsset(String id) async {
    final asset = await AssetEntity.fromId(id);
    if (asset != null) _remember([asset]);
    return asset;
  }

  /// All items of one album, newest first.
  Future<List<AssetEntity>> loadItems(
    String albumId, {
    required String allId,
    required String videosId,
  }) async {
    final AssetPathEntity? path;
    if (albumId == allId || albumId == videosId) {
      final paths = await PhotoManager.getAssetPathList(
        onlyAll: true,
        type: albumId == videosId ? RequestType.video : RequestType.common,
        filterOption: _filter(),
      );
      path = paths.isEmpty ? null : paths.first;
    } else {
      try {
        path = await AssetPathEntity.fromId(
          albumId,
          filterOption: _filter(),
          type: RequestType.common,
        );
      } on StateError {
        // The folder is gone: its last picture was deleted or moved, so
        // Android dropped the album. That is an EMPTY album, not an error
        // (an error would keep the old pictures on screen).
        return const <AssetEntity>[];
      }
    }
    if (path == null) return const <AssetEntity>[];

    final count = await path.assetCountAsync;
    if (count == 0) return const <AssetEntity>[];
    final assets = await path.getAssetListRange(start: 0, end: count);
    _remember(assets);
    return assets;
  }
}
