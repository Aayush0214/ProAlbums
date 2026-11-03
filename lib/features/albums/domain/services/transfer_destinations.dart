import 'package:proalbums/features/albums/domain/entities/album.dart';
import 'package:proalbums/features/albums/domain/services/album_grouping.dart';

/// The albums a Copy / Move can go into, in the order of the Albums tab
/// (Camera, Screenshots, then the other folders, then "Other albums").
///
/// Left out:
///  - All / Videos / Favorites (not folders, see [Album.isFolder]),
///  - [excludeAlbumId]: the album the items are being taken from.
List<Album> transferDestinations(
  AlbumSections sections, {
  String? excludeAlbumId,
}) =>
    [
      for (final album in [
        ...sections.top,
        ...sections.more,
        ...sections.other,
      ])
        if (album.isFolder && album.id != excludeAlbumId) album,
    ];
