import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/features/albums/domain/entities/album.dart';
import 'package:proalbums/features/albums/domain/services/album_grouping.dart';
import 'package:proalbums/shared/widgets/collapsing_sliver_app_bar.dart';

Album _album(String name, AlbumKind kind, [int count = 1]) =>
    Album(id: name, name: name, kind: kind, count: count);

void main() {
  group('albumKindOf', () {
    test('the "all" album', () {
      expect(albumKindOf(isAll: true, name: 'Recent'), AlbumKind.all);
    });
    test('camera and screenshots, whatever the capitals', () {
      expect(albumKindOf(isAll: false, name: 'Camera'), AlbumKind.camera);
      expect(albumKindOf(isAll: false, name: ' camera '), AlbumKind.camera);
      expect(
        albumKindOf(isAll: false, name: 'Screenshots'),
        AlbumKind.screenshots,
      );
    });
    test('anything else is a folder', () {
      expect(albumKindOf(isAll: false, name: 'WhatsApp'), AlbumKind.folder);
    });
  });

  group('splitAlbums', () {
    test('top order is All, Camera, Favorites, Videos, Screenshots', () {
      final sections = splitAlbums([
        _album('Favorites', AlbumKind.favorites),
        _album('Screenshots', AlbumKind.screenshots),
        _album('Videos', AlbumKind.videos),
        _album('Camera', AlbumKind.camera),
        _album('All', AlbumKind.all),
        _album('Pictures', AlbumKind.folder),
      ]);
      expect(
        [for (final a in sections.top) a.name],
        ['All', 'Camera', 'Favorites', 'Videos', 'Screenshots'],
      );
      expect([for (final a in sections.more) a.name], ['Pictures']);
    });

    test('other folders are sorted by name, capitals ignored', () {
      final sections = splitAlbums([
        _album('movies', AlbumKind.folder),
        _album('Download', AlbumKind.folder),
        _album('Pictures', AlbumKind.folder),
      ]);
      expect(
        [for (final a in sections.more) a.name],
        ['Download', 'movies', 'Pictures'],
      );
    });

    test('a missing Screenshots album is simply not there', () {
      final sections = splitAlbums([_album('All', AlbumKind.all)]);
      expect(sections.top, hasLength(1));
      expect(sections.more, isEmpty);
    });
  });

  group('Other albums', () {
    List<Album> folders(int n) => [
          for (var i = 0; i < n; i++) _album('F${i + 1}', AlbumKind.folder),
        ];

    test('every folder is listed in More albums, however many', () {
      final sections = splitAlbums(folders(8));
      expect(sections.more, hasLength(8));
      expect(sections.other, isEmpty);
    });

    test('a moved album goes to Other albums, the rest stay in More', () {
      final sections = splitAlbums(folders(4), movedToOthers: {'F2', 'F3'});
      expect([for (final a in sections.more) a.name], ['F1', 'F4']);
      expect([for (final a in sections.other) a.name], ['F2', 'F3']);
    });

    test('an unknown id in the saved set changes nothing', () {
      final sections = splitAlbums(folders(2), movedToOthers: {'gone'});
      expect(sections.more, hasLength(2));
      expect(sections.other, isEmpty);
    });
  });

  group('collapseProgress', () {
    test('is 0 at the top and 1 once scrolled far enough', () {
      expect(collapseProgress(0), 0);
      expect(collapseProgress(28), 0.5);
      expect(collapseProgress(500), 1);
      expect(collapseProgress(-20), 0);
    });
  });
}
