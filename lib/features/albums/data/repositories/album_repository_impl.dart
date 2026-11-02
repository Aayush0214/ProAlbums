import 'dart:async';
import 'dart:math' as math;

import 'package:fpdart/fpdart.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:proalbums/core/error/failures.dart';
import 'package:proalbums/core/logging/app_logger.dart';
import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/albums/data/datasources/photo_manager_album_data_source.dart';
import 'package:proalbums/features/albums/domain/entities/album.dart';
import 'package:proalbums/features/albums/domain/repositories/album_folder_repository.dart';
import 'package:proalbums/features/albums/domain/repositories/album_repository.dart';
import 'package:proalbums/features/albums/domain/services/album_grouping.dart';
import 'package:proalbums/features/favorites/domain/entities/favorite_location.dart';
import 'package:proalbums/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:proalbums/features/gallery/data/mappers/media_item_mapper.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';

final class AlbumRepositoryImpl implements AlbumRepository {
  const AlbumRepositoryImpl(this._dataSource, this._folders, this._favorites);

  final PhotoManagerAlbumDataSource _dataSource;
  final AlbumFolderRepository _folders;
  final FavoritesRepository _favorites;

  /// How many favorites are looked up at the same time.
  static const int _lookupBatch = 24;

  /// The favorites that still exist on the phone, newest first. A heart on a
  /// photo that is gone (deleted, in the trash) is skipped, not removed: the
  /// photo may come back (restore) and keeps its heart then.
  Future<List<AssetEntity>> _favoriteAssets() async {
    // Only what is really there: a picture in the trash is NOT a favorite of
    // the album (it comes back by itself when it is restored).
    final ids = (await _folders.existingMediaIds(await _favorites.getIds())).toList();
    final found = <AssetEntity>[];
    for (var i = 0; i < ids.length; i += _lookupBatch) {
      final batch = ids.sublist(i, math.min(i + _lookupBatch, ids.length));
      final assets = await Future.wait([
        for (final id in batch) _dataSource.loadAsset(id).catchError((Object _) => null),
      ]);
      found.addAll(assets.whereType<AssetEntity>());
    }
    found.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));

    // Remember each favorite's file name + folder (for backup / restore).
    unawaited(
      _favorites.saveLocations([
        for (final asset in found)
          if (asset.title != null && asset.relativePath != null)
            FavoriteLocation(
              mediaId: asset.id,
              displayName: asset.title!,
              relativePath: asset.relativePath!,
            ),
      ]),
    );
    return found;
  }

  @override
  FutureResult<List<Album>> getAlbums() async {
    try {
      final data = await _dataSource.loadAlbums(
        allId: kAllAlbumId,
        videosId: kVideosAlbumId,
      );
      // Folders that exist on the phone but have no picture yet (a new
      // album) are albums too: shown with 0 items.
      final names = {for (final item in data) item.name.toLowerCase()};
      final emptyFolders = [
        for (final name in await _folders.listFolderNames())
          if (!names.contains(name.toLowerCase())) name,
      ];
      final favorites = await _favoriteAssets();
      return right<Failure, List<Album>>([
        if (favorites.isNotEmpty)
          Album(
            id: kFavoritesAlbumId,
            name: 'Favorites',
            kind: AlbumKind.favorites,
            count: favorites.length,
            cover: MediaItemMapper.fromAsset(favorites.first),
          ),
        for (final name in emptyFolders)
          Album(
            id: '$kEmptyFolderPrefix$name',
            name: name,
            kind: AlbumKind.folder,
            count: 0,
          ),
        for (final item in data)
          Album(
            id: item.id,
            name: item.name,
            kind: item.id == kVideosAlbumId
                ? AlbumKind.videos
                : albumKindOf(isAll: item.isAll, name: item.name),
            count: item.count,
            cover: item.cover == null
                ? null
                : MediaItemMapper.fromAsset(item.cover!),
          ),
      ]);
    } on Object catch (error, stackTrace) {
      AppLogger.e('Could not load the albums', error: error, stackTrace: stackTrace);
      return left<Failure, List<Album>>(
        const MediaFailure('Could not load the albums.'),
      );
    }
  }

  @override
  Future<MediaItem?> getMediaItem(String id) async {
    try {
      // A picture in Android's trash can still be looked up by id, but it is
      // gone for the person.
      if (!(await _folders.existingMediaIds([id])).contains(id)) return null;
      final asset = await _dataSource.loadAsset(id);
      return asset == null ? null : MediaItemMapper.fromAsset(asset);
    } on Object {
      return null;
    }
  }

  @override
  FutureResult<List<MediaItem>> getAlbumItems(String albumId) async {
    if (albumId == kFavoritesAlbumId) {
      try {
        return right<Failure, List<MediaItem>>([
          for (final asset in await _favoriteAssets())
            MediaItemMapper.fromAsset(asset),
        ]);
      } on Object catch (error, stackTrace) {
        AppLogger.e('Could not load the favorites', error: error, stackTrace: stackTrace);
        return left<Failure, List<MediaItem>>(
          const MediaFailure('Could not load the favorites.'),
        );
      }
    }
    // An album that is only a folder so far has nothing inside.
    if (albumId.startsWith(kEmptyFolderPrefix)) {
      return right<Failure, List<MediaItem>>(const <MediaItem>[]);
    }
    try {
      final assets = await _dataSource.loadItems(
        albumId,
        allId: kAllAlbumId,
        videosId: kVideosAlbumId,
      );
      return right<Failure, List<MediaItem>>([
        for (final asset in assets) MediaItemMapper.fromAsset(asset),
      ]);
    } on Object catch (error, stackTrace) {
      AppLogger.e('Could not load the album', error: error, stackTrace: stackTrace);
      return left<Failure, List<MediaItem>>(
        const MediaFailure('Could not load this album.'),
      );
    }
  }
}
