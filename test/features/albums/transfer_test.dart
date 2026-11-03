import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/features/albums/domain/entities/album.dart';
import 'package:proalbums/features/albums/domain/entities/folder_outcomes.dart';
import 'package:proalbums/features/albums/domain/entities/transfer_target.dart';
import 'package:proalbums/features/albums/domain/services/album_grouping.dart';
import 'package:proalbums/features/albums/domain/services/transfer_destinations.dart';
import 'package:proalbums/features/albums/presentation/widgets/transfer_flow.dart';

Album _album(String id, AlbumKind kind, {String? name, int count = 1}) =>
    Album(id: id, name: name ?? id, kind: kind, count: count);

void main() {
  group('transferDestinations', () {
    final sections = AlbumSections(
      top: [
        _album(kAllAlbumId, AlbumKind.all, name: 'All'),
        _album('1', AlbumKind.camera, name: 'Camera'),
        _album(kFavoritesAlbumId, AlbumKind.favorites, name: 'Favorites'),
        _album(kVideosAlbumId, AlbumKind.videos, name: 'Videos'),
        _album('2', AlbumKind.screenshots, name: 'Screenshots'),
      ],
      more: [
        _album('3', AlbumKind.folder, name: 'Movies'),
        _album('${kEmptyFolderPrefix}Trip', AlbumKind.folder,
            name: 'Trip', count: 0),
      ],
      other: [_album('4', AlbumKind.folder, name: 'WhatsApp')],
    );

    test('only real folders, in the order of the Albums tab', () {
      expect(
        transferDestinations(sections).map((a) => a.name),
        ['Camera', 'Screenshots', 'Movies', 'Trip', 'WhatsApp'],
      );
    });

    test('the album the items come from is left out', () {
      expect(
        transferDestinations(sections, excludeAlbumId: '3').map((a) => a.name),
        ['Camera', 'Screenshots', 'Trip', 'WhatsApp'],
      );
    });
  });

  group('TransferTarget.of', () {
    test('an album with files is found by its id', () {
      final target = TransferTarget.of(_album('-161', AlbumKind.camera,
          name: 'Camera'));
      expect(target.albumId, '-161');
      expect(target.name, 'Camera');
    });

    test('an empty album is the folder Pictures/<name>', () {
      final target = TransferTarget.of(
        _album('${kEmptyFolderPrefix}Trip', AlbumKind.folder,
            name: 'Trip', count: 0),
      );
      expect(target.albumId, isNull);
      expect(target.name, 'Trip');
    });
  });

  group('transferMessage', () {
    String? message(TransferMethod method, TransferResult? result) =>
        transferMessage(method: method, albumName: 'Trip', result: result);

    test('everything done', () {
      expect(
        message(TransferMethod.move,
            const TransferResult(cancelled: false, done: 3)),
        'Moved 3 items to "Trip".',
      );
      expect(
        message(TransferMethod.copy,
            const TransferResult(cancelled: false, done: 1)),
        'Copied 1 item to "Trip".',
      );
    });

    test('some failed', () {
      expect(
        message(TransferMethod.copy,
            const TransferResult(cancelled: false, done: 2, failed: 1)),
        'Copied 2 items to "Trip". 1 could not be copied.',
      );
    });

    test('nothing worked', () {
      expect(
        message(TransferMethod.move,
            const TransferResult(cancelled: false, failed: 2)),
        'Could not move the selected items to "Trip".',
      );
      expect(
        message(TransferMethod.copy, null),
        'Could not copy the selected items to "Trip".',
      );
    });

    test('cancelled in Android\'s dialog: no message', () {
      expect(
        message(TransferMethod.move, const TransferResult(cancelled: true)),
        isNull,
      );
    });
  });
}
