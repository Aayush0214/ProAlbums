import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:proalbums/app/router/app_routes.dart';
import 'package:proalbums/features/classification/data/face_repository.dart';
import 'package:proalbums/features/classification/presentation/classification_providers.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/memories/data/memory_repository.dart';
import 'package:proalbums/features/memories/domain/memory_rules.dart';
import 'package:proalbums/features/memories/presentation/memory_providers.dart';
import 'package:proalbums/features/search/presentation/search_providers.dart';
import 'package:proalbums/shared/widgets/app_snack_bar.dart';
import 'package:proalbums/shared/widgets/confirm_dialog.dart';
import 'package:proalbums/shared/widgets/text_input_dialog.dart';

/// Tap on a memory: plays its video.
void openMemory(BuildContext context, StoredMemory memory) =>
    unawaited(context.push<void>(AppRoutes.memoryPlayer(memory.id)));

/// The person page's ▶: that person's memory (the one the rules made, or
/// a new one from all the person's pictures), played at once.
Future<void> playPersonMemory(
  BuildContext context,
  WidgetRef ref,
  PersonSummary person,
) async {
  final toast = AppToast.of(context);
  final faces = await ref.read(faceStoreProvider).facesOf(person.id);
  // The RIGHT dates (EXIF / file name), like the memories engine: the
  // faces keep MediaStore's date, which for copied pictures is the copy
  // time (all one moment).
  final library = await ref.read(libraryMediaProvider.future);
  final takenOf = {for (final m in library.media) m.id: m.takenMs};
  final best = <String, StoredFace>{};
  for (final f in faces) {
    if (library.undated.contains(f.mediaId)) continue;
    final known = best[f.mediaId];
    if (known == null || f.quality > known.quality) best[f.mediaId] = f;
  }
  final draft = personMemory(person.id, person.name ?? 'People', [
    for (final f in best.values)
      (
        id: f.mediaId,
        takenMs: takenOf[f.mediaId] ?? f.takenMs,
        place: '',
        people: {person.id},
        quality: f.quality,
        biggestFace: 0,
        groupPhoto: false,
      ),
  ]);
  if (draft == null) {
    toast.show('Not enough photos for a memory yet');
    return;
  }
  final id = await ref.read(memoryStoreProvider).ensure(draft);
  ref.read(memoryScanProvider.notifier).changed();
  if (context.mounted) {
    unawaited(context.push<void>(AppRoutes.memoryPlayer(id)));
  }
}

/// ⋮ > View Gallery: the memory's shown pictures.
void viewMemoryGallery(BuildContext context, StoredMemory memory) =>
    unawaited(context.push<void>(AppRoutes.memoryGallery(memory.id)));

/// Gallery management (from View Gallery's ⋮ and, later, the player).
void manageMemory(BuildContext context, int memoryId) =>
    unawaited(context.push<void>(AppRoutes.memoryManage(memoryId)));

/// ⋮ > Rename.
Future<void> renameMemory(
  BuildContext context,
  WidgetRef ref,
  StoredMemory memory,
) async {
  final name = await showTextInputDialog(
    context,
    title: 'Rename',
    initial: memory.title,
  );
  if (name == null || name == memory.title) return;
  await ref.read(memoryStoreProvider).rename(memory.id, name);
  ref.read(memoryScanProvider.notifier).changed();
}

/// ⋮ > Delete memories / Memories page > Delete: the memories go, their
/// pictures stay. true = deleted.
Future<bool> deleteMemories(
  BuildContext context,
  WidgetRef ref,
  List<int> ids,
) async {
  if (ids.isEmpty) return false;
  final ok = await showConfirmDialog(
    context,
    title: ids.length == 1
        ? 'Permanently delete this memory?'
        : 'Permanently delete ${ids.length} memories?',
    confirmLabel: 'Permanently delete',
  );
  if (ok != true) return false;
  await ref.read(memoryStoreProvider).delete(ids);
  ref.read(memoryScanProvider.notifier).changed();
  return true;
}

/// View Gallery > Set as cover ([albumId] = memoryAlbumId). true = the
/// selection ends.
Future<bool> setMemoryCover(
  BuildContext context,
  WidgetRef ref,
  String? albumId,
  MediaItem item,
) async {
  final memoryId = memoryIdOfAlbum(albumId);
  if (memoryId == null) return false;
  final toast = AppToast.of(context);
  await ref.read(memoryStoreProvider).setCover(memoryId, item.id);
  ref.read(memoryScanProvider.notifier).changed();
  toast.show('Set as cover');
  return true;
}

/// View Gallery > Remove: the pictures leave the memory's shown pictures
/// (nothing is deleted; Gallery management can show them again). true =
/// the selection ends.
Future<bool> removeFromMemory(
  BuildContext context,
  WidgetRef ref,
  String? albumId,
  List<MediaItem> items,
) async {
  final memoryId = memoryIdOfAlbum(albumId);
  if (memoryId == null || items.isEmpty) return false;
  await ref.read(memoryStoreProvider).hide(memoryId, [
    for (final item in items) item.id,
  ]);
  ref.read(memoryScanProvider.notifier).changed();
  return true;
}
