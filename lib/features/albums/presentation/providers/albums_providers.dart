import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proalbums/features/albums/data/datasources/photo_manager_album_data_source.dart';
import 'package:proalbums/features/albums/data/repositories/album_repository_impl.dart';
import 'package:proalbums/features/albums/data/repositories/method_channel_album_folder_repository.dart';
import 'package:proalbums/features/albums/domain/entities/album.dart';
import 'package:proalbums/features/albums/domain/repositories/album_folder_repository.dart';
import 'package:proalbums/features/albums/domain/repositories/album_repository.dart';
import 'package:proalbums/features/albums/domain/services/album_grouping.dart';
import 'package:proalbums/features/albums/domain/usecases/create_album.dart';
import 'package:proalbums/features/albums/domain/usecases/get_album_items.dart';
import 'package:proalbums/features/albums/domain/usecases/get_albums.dart';
import 'package:proalbums/features/albums/domain/usecases/transfer_to_album.dart';
import 'package:proalbums/features/albums/presentation/providers/album_prefs_controller.dart';
import 'package:proalbums/features/favorites/presentation/providers/favorites_providers.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/domain/entities/media_page_request.dart';
import 'package:proalbums/features/gallery/domain/entities/photos_view_settings.dart';
import 'package:proalbums/features/gallery/presentation/providers/library_reload.dart';
import 'package:proalbums/features/gallery/presentation/providers/media_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'albums_providers.g.dart';

@Riverpod(keepAlive: true)
PhotoManagerAlbumDataSource albumDataSource(Ref ref) =>
    PhotoManagerAlbumDataSource(
      remember: ref.watch(photoManagerMediaDataSourceProvider).remember,
    );

@Riverpod(keepAlive: true)
AlbumFolderRepository albumFolderRepository(Ref ref) =>
    const MethodChannelAlbumFolderRepository();

@Riverpod(keepAlive: true)
CreateAlbumUseCase createAlbumUseCase(Ref ref) =>
    CreateAlbumUseCase(ref.watch(albumFolderRepositoryProvider));

@Riverpod(keepAlive: true)
TransferToAlbumUseCase transferToAlbumUseCase(Ref ref) =>
    TransferToAlbumUseCase(ref.watch(albumFolderRepositoryProvider));

@Riverpod(keepAlive: true)
AlbumRepository albumRepository(Ref ref) =>
    AlbumRepositoryImpl(
      ref.watch(albumDataSourceProvider),
      ref.watch(albumFolderRepositoryProvider),
      ref.watch(favoritesRepositoryProvider),
    );

@Riverpod(keepAlive: true)
GetAlbumsUseCase getAlbumsUseCase(Ref ref) =>
    GetAlbumsUseCase(ref.watch(albumRepositoryProvider));

@Riverpod(keepAlive: true)
GetAlbumItemsUseCase getAlbumItemsUseCase(Ref ref) =>
    GetAlbumItemsUseCase(ref.watch(albumRepositoryProvider));

/// The albums of the Albums tab, already in their sections. The person's
/// own choices (albums sent to "Other albums", chosen covers) are applied.
@riverpod
Future<AlbumSections> albumSections(Ref ref) async {
  reloadOnLibraryChange(ref);
  // Loads again when a heart is added / removed (the Favorites tile appears,
  // disappears or changes its count). `.future` waits for the first value,
  // so the first load is not done twice.
  await ref.watch(favoriteIdsProvider.future);
  final prefs = ref.watch(albumPrefsControllerProvider);
  final repository = ref.watch(albumRepositoryProvider);
  final result = await ref.watch(getAlbumsUseCaseProvider)();
  final albums = result.fold((failure) => throw failure, (list) => list);

  // A chosen cover only counts while its album exists and the picture is
  // still there (not deleted, not in the trash). Otherwise the album shows
  // its newest picture again, and the old choice is forgotten, so an album
  // that comes back later (Favorites, a re-created folder) starts fresh.
  final stale = <String>{
    for (final name in prefs.covers.keys)
      if (!albums.any((album) => album.name == name)) name,
  };
  final withCovers = await Future.wait([
    for (final album in albums)
      () async {
        final coverId = prefs.covers[album.name];
        if (coverId == null) return album;
        final item = await repository.getMediaItem(coverId);
        if (item == null) {
          stale.add(album.name);
          return album;
        }
        return album.withCover(item);
      }(),
  ]);
  if (stale.isNotEmpty) {
    final notifier = ref.read(albumPrefsControllerProvider.notifier);
    // Not while this provider is still being built.
    unawaited(Future<void>(() => notifier.dropCovers(stale)));
  }
  return splitAlbums(withCovers, movedToOthers: prefs.others);
}

/// Everything in one album, newest first (as loaded).
@riverpod
Future<List<MediaItem>> albumItems(Ref ref, String albumId) async {
  reloadOnLibraryChange(ref);
  // The Favorites album follows the hearts too.
  if (albumId == kFavoritesAlbumId) {
    await ref.watch(favoriteIdsProvider.future);
  }
  final result = await ref.watch(getAlbumItemsUseCaseProvider)(albumId);
  return result.fold((failure) => throw failure, (items) => items);
}

/// Zoom level and browsing order of the album grids. The SAME class as the
/// Photos tab (same zoom steps, same menu rules), but its own value, so
/// zooming an album does not change the Photos tab. Kept while the app runs.
@Riverpod(keepAlive: true)
class AlbumViewSettings extends _$AlbumViewSettings {
  @override
  PhotosViewSettings build() => const PhotosViewSettings();

  void zoomIn() {
    if (state.canZoomIn) state = state.copyWith(columns: state.columnsZoomedIn);
  }

  void zoomOut() {
    if (state.canZoomOut) {
      state = state.copyWith(columns: state.columnsZoomedOut);
    }
  }

  void setOrder(MediaSortOrder order) => state = state.copyWith(order: order);
}

/// What the album grid shows AND what the viewer swipes through, in the chosen
/// order. A plain list, so it also works as the viewer's `items`.
@riverpod
List<MediaItem> albumDisplayItems(Ref ref, String albumId) {
  final items = ref.watch(albumItemsProvider(albumId)).value ??
      const <MediaItem>[];
  final order = ref.watch(albumViewSettingsProvider.select((s) => s.order));
  return order == MediaSortOrder.oldestFirst
      ? items.reversed.toList(growable: false)
      : items;
}
