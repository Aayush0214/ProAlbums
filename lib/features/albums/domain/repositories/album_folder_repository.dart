import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/albums/domain/entities/folder_outcomes.dart';
import 'package:proalbums/features/albums/domain/entities/transfer_target.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';

/// The real folders behind the albums: Pictures/(album name).
abstract interface class AlbumFolderRepository {
  /// Makes the folder, also when it stays empty.
  FutureResult<CreateFolderOutcome> createFolder(String name);

  /// Names of the folders inside Pictures (to show empty albums too).
  Future<List<String>> listFolderNames();

  /// true when the album is the folder Pictures/(name) (so it can be renamed
  /// by moving its files to another folder in Pictures).
  Future<bool> isPicturesFolder(String name);

  /// Renames a folder that has no files in it. false when it did not work.
  Future<bool> renameEmptyFolder(String from, String to);

  /// Deletes the folder when nothing is left in it (after a rename).
  Future<void> removeFolderIfEmpty(String name);

  /// Of these media ids, the ones that still exist and are not in Android's
  /// trash. On any error all ids come back (nothing is hidden by mistake).
  Future<Set<String>> existingMediaIds(Iterable<String> ids);

  /// Copies or moves [items] into the folder of [target].
  FutureResult<TransferResult> transfer(
    List<MediaItem> items,
    TransferTarget target, {
    required bool move,
  });
}
