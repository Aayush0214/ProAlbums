import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/actions/media_actions.dart';

MediaItem _item(MediaType type) => MediaItem(
  id: '1',
  type: type,
  createdAt: DateTime(2026, 10, 12),
  width: 100,
  height: 100,
);

void main() {
  group('selection bar per screen', () {
    test('library, album and search: the system gallery bar', () {
      for (final context in [
        MediaContext.library,
        MediaContext.album,
        MediaContext.search,
      ]) {
        final actions = selectionActionsFor(context);
        expect(actions.bar, [
          MediaAction.share,
          MediaAction.moveCopy,
          MediaAction.create,
          MediaAction.delete,
        ]);
        expect(actions.more, [
          MediaAction.hide,
          MediaAction.copyToClipboard,
          MediaAction.pdfPpt,
          MediaAction.print,
        ]);
      }
    });

    test('Recently deleted: Restore and Delete, no More', () {
      final actions = selectionActionsFor(MediaContext.trash);
      expect(actions.bar, [MediaAction.restore, MediaAction.deleteForever]);
      expect(actions.more, isEmpty);
    });

    test('every bar button has an icon', () {
      for (final context in MediaContext.values) {
        for (final action in selectionActionsFor(context).bar) {
          expect(action.icon, isNotNull, reason: action.name);
        }
      }
    });
  });

  group('greyed out More options (like the system gallery)', () {
    bool on(MediaAction a, {required bool image, required bool video}) =>
        isActionEnabled(a, hasImage: image, hasVideo: video);

    test('only pictures: all on', () {
      for (final a in selectionActionsFor(MediaContext.library).more) {
        expect(on(a, image: true, video: false), isTrue, reason: a.name);
      }
    });

    test('pictures + videos: Hide only (PDF/PPT is images only)', () {
      expect(on(MediaAction.hide, image: true, video: true), isTrue);
      expect(on(MediaAction.pdfPpt, image: true, video: true), isFalse);
      expect(
        on(MediaAction.copyToClipboard, image: true, video: true),
        isFalse,
      );
      expect(on(MediaAction.print, image: true, video: true), isFalse);
    });

    test('only videos: Hide only', () {
      expect(on(MediaAction.hide, image: false, video: true), isTrue);
      expect(on(MediaAction.pdfPpt, image: false, video: true), isFalse);
      expect(
        on(MediaAction.copyToClipboard, image: false, video: true),
        isFalse,
      );
      expect(on(MediaAction.print, image: false, video: true), isFalse);
    });
  });

  group('viewer More menu', () {
    test('a photo has 13 options, starting like the system gallery', () {
      final actions = viewerMoreActionsFor(
        MediaContext.library,
        _item(MediaType.image),
      );
      expect(actions, hasLength(13));
      expect(actions.first, MediaAction.setAsWallpaper);
      expect(actions, contains(MediaAction.rotate));
      expect(actions, isNot(contains(MediaAction.convertToH264)));
    });

    test('a video has its own 8 options', () {
      final actions = viewerMoreActionsFor(
        MediaContext.album,
        _item(MediaType.video),
      );
      expect(actions, hasLength(8));
      expect(actions, contains(MediaAction.convertToH264));
      expect(actions, isNot(contains(MediaAction.rotate)));
    });

    test('Recently deleted: no More menu', () {
      expect(
        viewerMoreActionsFor(MediaContext.trash, _item(MediaType.image)),
        isEmpty,
      );
    });
  });

  group('viewer bar per screen', () {
    test('Recently deleted: only Restore and Delete, no heart', () {
      expect(viewerBarActionsFor(MediaContext.trash), [
        MediaAction.restore,
        MediaAction.deleteForever,
      ]);
      expect(viewerShowsFavorite(MediaContext.trash), isFalse);
    });

    test('other screens keep the normal bar and the heart', () {
      for (final context in [
        MediaContext.library,
        MediaContext.album,
        MediaContext.search,
      ]) {
        expect(viewerBarActionsFor(context), isNull);
        expect(viewerShowsFavorite(context), isTrue);
      }
    });
  });

  test('only delete-for-good is destructive (shown in the error colour)', () {
    expect(
      [for (final a in MediaAction.values) if (a.destructive) a],
      [MediaAction.deleteForever],
    );
  });
}
