import 'dart:async';
import 'dart:collection';

import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:proalbums/features/gallery/data/datasources/media_local_data_source.dart';
import 'package:proalbums/features/gallery/domain/entities/media_page_request.dart';

/// photo_manager implementation (MediaStore on Android, PhotoKit on iOS).
final class PhotoManagerMediaDataSource implements MediaLocalDataSource {
  static const int _maxCachedAssets = 3000;

  // By default photo_manager hides items whose width/height or duration is
  // missing in MediaStore (e.g. a screenshot not fully indexed yet), so the
  // library count would be lower than the system gallery. We want everything.
  static const FilterOption _imageOption = FilterOption(
    sizeConstraint: SizeConstraint(ignoreSize: true),
  );
  static const FilterOption _videoOption = FilterOption(
    sizeConstraint: SizeConstraint(ignoreSize: true),
    durationConstraint: DurationConstraint(allowNullable: true),
  );

  // Thumbnails need the plugin's AssetEntity, but the rest of the app only
  // knows ids. We remember recently loaded AssetEntity objects here, so a
  // thumbnail request does not need an extra platform call to find the item.
  final LinkedHashMap<String, AssetEntity> _assetCache =
      LinkedHashMap<String, AssetEntity>();

  // The "all photos" album per (kind, order). Cleared when the library changes.
  final Map<String, AssetPathEntity> _pathCache = <String, AssetPathEntity>{};

  // Starts listening to the OS only while someone listens to the stream.
  late final StreamController<void> _changes = StreamController<void>.broadcast(
    onListen: _startWatching,
    onCancel: _stopWatching,
  );

  @override
  Stream<void> get libraryChanges => _changes.stream;

  @override
  Future<List<AssetEntity>> getAssets({
    required int page,
    required int size,
    required MediaKind kind,
    required MediaSortOrder order,
  }) async {
    final path = await _allPhotosPath(kind, order);
    if (path == null) return const <AssetEntity>[];

    final assets = await path.getAssetListPaged(page: page, size: size);
    _remember(assets);
    return assets;
  }

  @override
  Future<int> getCount(MediaKind kind) async {
    final path = await _allPhotosPath(kind, MediaSortOrder.newestFirst);
    if (path == null) return 0;
    return path.assetCountAsync;
  }

  @override
  Future<Uint8List?> getThumbnail({required String id, required int size}) async {
    final asset = _assetCache[id] ?? await AssetEntity.fromId(id);
    if (asset == null) return null;
    return asset.thumbnailDataWithSize(
      ThumbnailSize.square(size),
      quality: 80,
    );
  }

  Future<void> dispose() => _changes.close();

  Future<AssetPathEntity?> _allPhotosPath(
    MediaKind kind,
    MediaSortOrder order,
  ) async {
    final key = '${kind.name}-${order.name}';
    final cached = _pathCache[key];
    if (cached != null) return cached;

    final paths = await PhotoManager.getAssetPathList(
      onlyAll: true,
      type: _requestType(kind),
      filterOption: FilterOptionGroup(
        imageOption: _imageOption,
        videoOption: _videoOption,
        orders: [
          OrderOption(
            type: OrderOptionType.createDate,
            asc: order == MediaSortOrder.oldestFirst,
          ),
        ],
      ),
    );
    if (paths.isEmpty) return null;
    return _pathCache[key] = paths.first;
  }

  RequestType _requestType(MediaKind kind) => switch (kind) {
        MediaKind.all => RequestType.common,
        MediaKind.images => RequestType.image,
        MediaKind.videos => RequestType.video,
      };

  void _remember(List<AssetEntity> assets) {
    for (final asset in assets) {
      _assetCache[asset.id] = asset;
    }
    while (_assetCache.length > _maxCachedAssets) {
      _assetCache.remove(_assetCache.keys.first);
    }
  }

  void _startWatching() {
    PhotoManager.addChangeCallback(_onLibraryChanged);
    unawaited(PhotoManager.startChangeNotify());
  }

  void _stopWatching() {
    PhotoManager.removeChangeCallback(_onLibraryChanged);
    unawaited(PhotoManager.stopChangeNotify());
  }

  void _onLibraryChanged(MethodCall call) {
    _pathCache.clear(); // counts / order are stale now
    _changes.add(null);
  }
}
