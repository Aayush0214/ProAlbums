import 'dart:typed_data';

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

/// The small picture of one item in the trash.
@riverpod
Future<Uint8List?> trashThumbnail(
  Ref ref,
  String id,
  bool isVideo,
  int size,
) =>
    ref
        .watch(trashRepositoryProvider)
        .thumbnail(id: id, isVideo: isVideo, size: size);
