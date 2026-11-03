import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/domain/entities/photos_view_settings.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_row.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_rows_builder.dart';
import 'package:proalbums/features/gallery/presentation/providers/library_reload.dart';
import 'package:proalbums/features/trash/data/repositories/method_channel_trash_repository.dart';
import 'package:proalbums/features/trash/domain/entities/trashed_item.dart';
import 'package:proalbums/features/trash/domain/repositories/trash_repository.dart';
import 'package:proalbums/features/trash/domain/usecases/delete_forever.dart';
import 'package:proalbums/features/trash/domain/usecases/get_trashed_items.dart';
import 'package:proalbums/features/trash/domain/usecases/media_management_access.dart';
import 'package:proalbums/features/trash/domain/usecases/move_to_trash.dart';
import 'package:proalbums/features/trash/domain/usecases/restore_from_trash.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'trash_providers.g.dart';

@Riverpod(keepAlive: true)
TrashRepository trashRepository(Ref ref) => const MethodChannelTrashRepository();

@Riverpod(keepAlive: true)
MoveToTrashUseCase moveToTrashUseCase(Ref ref) =>
    MoveToTrashUseCase(ref.watch(trashRepositoryProvider));

@Riverpod(keepAlive: true)
MediaManagementAccessUseCase mediaManagementAccessUseCase(Ref ref) =>
    MediaManagementAccessUseCase(ref.watch(trashRepositoryProvider));

@Riverpod(keepAlive: true)
GetTrashedItemsUseCase getTrashedItemsUseCase(Ref ref) =>
    GetTrashedItemsUseCase(ref.watch(trashRepositoryProvider));

@Riverpod(keepAlive: true)
RestoreFromTrashUseCase restoreFromTrashUseCase(Ref ref) =>
    RestoreFromTrashUseCase(ref.watch(trashRepositoryProvider));

@Riverpod(keepAlive: true)
DeleteForeverUseCase deleteForeverUseCase(Ref ref) =>
    DeleteForeverUseCase(ref.watch(trashRepositoryProvider));

/// What is in "Recently deleted". Loads again a moment after the phone's
/// library changed (a delete, a restore).
@riverpod
Future<List<TrashedItem>> trashedItems(Ref ref) async {
  reloadOnLibraryChange(ref);
  final result = await ref.watch(getTrashedItemsUseCaseProvider)();
  return result.fold((failure) => throw failure, (items) => items);
}


/// The trash as plain pictures, in its order: what the shared grid shows and
/// the selection looks ids up in.
@riverpod
List<MediaItem> trashMediaItems(Ref ref) => [
  for (final trashed in ref.watch(trashedItemsProvider).value ?? const <TrashedItem>[])
    trashed.item,
];

/// When each picture leaves the trash for good, by id (for the "29 days"
/// label on the tiles).
@riverpod
Map<String, DateTime?> trashExpiryById(Ref ref) => {
  for (final trashed in ref.watch(trashedItemsProvider).value ?? const <TrashedItem>[])
    trashed.id: trashed.expiresAt,
};

/// Zoom of the Recently deleted grid: the same steps and rules as every
/// grid, its own value. Kept while the app runs.
@Riverpod(keepAlive: true)
class TrashViewSettings extends _$TrashViewSettings {
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
}

/// The trash cut into grid rows (one flat grid, no date headers).
@riverpod
List<GalleryRow> trashGalleryRows(Ref ref) => GalleryRowsBuilder.buildFlat(
  items: ref.watch(trashMediaItemsProvider),
  columns: ref.watch(trashViewSettingsProvider.select((s) => s.columns)),
  alignToEnd: false,
);
