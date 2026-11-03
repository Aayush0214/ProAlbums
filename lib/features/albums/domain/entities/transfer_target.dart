import 'package:proalbums/features/albums/domain/entities/album.dart';

/// Where a Copy / Move puts the files.
///
/// An album on the phone can live anywhere (DCIM/Camera, Movies,
/// Pictures/Screenshots…), so an existing album is found by its MediaStore
/// id and the files go into ITS folder. A new (or still empty) album has no
/// files yet to find it by, so it is the folder `Pictures/<name>`.
final class TransferTarget {
  /// The folder `Pictures/<name>` (a new or still empty album).
  const TransferTarget.newFolder(this.name) : albumId = null;

  /// An album that already has files: they go into the same folder.
  const TransferTarget.album({required String this.albumId, required this.name});

  /// The target of [album]. Only for real folders ([Album.isFolder]).
  factory TransferTarget.of(Album album) =>
      album.id.startsWith(kEmptyFolderPrefix)
          ? TransferTarget.newFolder(album.name)
          : TransferTarget.album(albumId: album.id, name: album.name);

  /// The album's name, shown to the person ("Moved 3 items to …").
  final String name;

  /// MediaStore bucket id of an existing album. null = Pictures/[name].
  final String? albumId;
}
