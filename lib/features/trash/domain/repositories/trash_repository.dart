import 'dart:typed_data';

import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/trash/domain/entities/trashed_item.dart';

/// What happened to a delete.
enum TrashOutcome {
  /// The items are in the trash.
  trashed,

  /// The person said no in Android's own dialog. Nothing changed.
  cancelled,
}

/// What happened to a restore / delete for good.
enum TrashActionOutcome {
  /// It worked.
  done,

  /// The person said no in Android's own dialog. Nothing changed.
  cancelled,
}

/// Android's trash: files stay on the phone for 30 days, then Android removes
/// them for good.
abstract interface class TrashRepository {
  /// "Media management" access is on: deleting needs no Android dialog.
  Future<bool> hasMediaManagement();

  /// Opens the Settings screen where the person turns that access on. Answers
  /// with the new state when they come back.
  Future<bool> requestMediaManagement();

  FutureResult<TrashOutcome> moveToTrash(List<MediaItem> items);

  /// Everything in the trash, the most recently deleted first.
  FutureResult<List<TrashedItem>> getTrashed();

  /// Takes the items out of the trash: they are back in their albums.
  FutureResult<TrashActionOutcome> restore(List<MediaItem> items);

  /// Deletes the items for good. This cannot be undone.
  FutureResult<TrashActionOutcome> deleteForever(List<MediaItem> items);

  /// A small picture (JPEG) of an item in the trash; null when it cannot be
  /// read. Read through MediaStore by the id (the file path of a trashed item
  /// is hidden from apps).
  Future<Uint8List?> thumbnail({
    required String id,
    required bool isVideo,
    required int size,
  });

  /// Where the video player can open a video that is in the trash (the
  /// normal address does not find trashed items).
  String playableVideoUri(String id);
}
