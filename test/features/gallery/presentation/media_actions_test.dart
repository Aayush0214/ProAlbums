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
          MediaAction.collage,
          MediaAction.delete,
        ]);
        expect(actions.more, [
          MediaAction.hide,
          MediaAction.copyToClipboard,
          MediaAction.convertPdf,
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

    test('pictures + videos: Hide only (Convert PDF is images only)', () {
      expect(on(MediaAction.hide, image: true, video: true), isTrue);
      expect(on(MediaAction.convertPdf, image: true, video: true), isFalse);
      expect(
        on(MediaAction.copyToClipboard, image: true, video: true),
        isFalse,
      );
      expect(on(MediaAction.print, image: true, video: true), isFalse);
    });

    test('only videos: Hide only', () {
      expect(on(MediaAction.hide, image: false, video: true), isTrue);
      expect(on(MediaAction.convertPdf, image: false, video: true), isFalse);
      expect(
        on(MediaAction.copyToClipboard, image: false, video: true),
        isFalse,
      );
      expect(on(MediaAction.print, image: false, video: true), isFalse);
    });
  });

  group('viewer More menu', () {
    test('a photo has 11 options (no Screen Mirroring, no wallpaper)', () {
      final actions = viewerMoreActionsFor(
        MediaContext.library,
        _item(MediaType.image),
      );
      expect(actions, hasLength(11));
      expect(actions.first, MediaAction.googleLens);
      expect(actions, contains(MediaAction.rotate));
      expect(actions, isNot(contains(MediaAction.convertToH264)));
    });

    test(
      'a video has its own 6 options (no Screen Mirroring, no wallpaper)',
      () {
        final actions = viewerMoreActionsFor(
          MediaContext.album,
          _item(MediaType.video),
        );
        expect(actions, hasLength(6));
        expect(actions, contains(MediaAction.convertToH264));
        expect(actions, isNot(contains(MediaAction.rotate)));
      },
    );

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

  test('delete for good and delete from the vault are destructive (red)', () {
    expect(
      [
        for (final a in MediaAction.values)
          if (a.destructive) a,
      ],
      [MediaAction.deleteForever, MediaAction.deleteHidden],
    );
  });

  test('vault: Unhide and Delete only, no More, no heart', () {
    expect(selectionActionsFor(MediaContext.vault).bar, [
      MediaAction.unhide,
      MediaAction.deleteHidden,
    ]);
    expect(selectionActionsFor(MediaContext.vault).more, isEmpty);
    expect(viewerBarActionsFor(MediaContext.vault), [
      MediaAction.unhide,
      MediaAction.deleteHidden,
    ]);
    expect(
      viewerMoreActionsFor(MediaContext.vault, _item(MediaType.image)),
      isEmpty,
    );
    expect(viewerShowsFavorite(MediaContext.vault), isFalse);
    expect(viewerShowsInfo(MediaContext.vault), isTrue);
  });

  test('preview (Convert PDF pages): look only, no actions anywhere', () {
    final image = _item(MediaType.image);
    expect(selectionActionsFor(MediaContext.preview).bar, isEmpty);
    expect(selectionActionsFor(MediaContext.preview).more, isEmpty);
    expect(viewerMoreActionsFor(MediaContext.preview, image), isEmpty);
    expect(viewerBarActionsFor(MediaContext.preview), isEmpty);
    expect(viewerShowsFavorite(MediaContext.preview), isFalse);
    expect(viewerShowsInfo(MediaContext.preview), isFalse);
    expect(viewerShowsInfo(MediaContext.library), isTrue);
  });

  test('person: Set as cover (one only) and Not this person', () {
    expect(selectionActionsFor(MediaContext.person).bar, [
      MediaAction.share,
      MediaAction.setAsCover,
      MediaAction.notThisPerson,
      MediaAction.delete,
    ]);
    expect(
      isActionEnabled(
        MediaAction.setAsCover,
        hasImage: true,
        hasVideo: false,
        count: 2,
      ),
      isFalse,
    );
    expect(
      isActionEnabled(MediaAction.setAsCover, hasImage: true, hasVideo: false),
      isTrue,
    );
    expect(actionDependsOnSelection(MediaAction.setAsCover), isTrue);
    // Last in the viewer's More, and only when opened from a person.
    expect(
      viewerMoreActionsFor(MediaContext.person, _item(MediaType.image)).last,
      MediaAction.notThisPerson,
    );
    expect(
      viewerMoreActionsFor(MediaContext.album, _item(MediaType.image)),
      isNot(contains(MediaAction.notThisPerson)),
    );
    expect(viewerBarActionsFor(MediaContext.person), isNull);
    expect(viewerShowsFavorite(MediaContext.person), isTrue);
  });

  test('thing: "Remove this type" last in More and in the viewer', () {
    expect(
      selectionActionsFor(MediaContext.thing).more.last,
      MediaAction.removeThisType,
    );
    expect(
      viewerMoreActionsFor(MediaContext.thing, _item(MediaType.image)).last,
      MediaAction.removeThisType,
    );
    expect(
      viewerMoreActionsFor(MediaContext.album, _item(MediaType.image)),
      isNot(contains(MediaAction.removeThisType)),
    );
  });

  test('person from Search: the library bar, Not this person last in More', () {
    final actions = selectionActionsFor(MediaContext.searchPerson);
    expect(actions.bar, selectionActionsFor(MediaContext.library).bar);
    expect(actions.more.last, MediaAction.notThisPerson);
    expect(
      viewerMoreActionsFor(
        MediaContext.searchPerson,
        _item(MediaType.image),
      ).last,
      MediaAction.notThisPerson,
    );
    expect(viewerBarActionsFor(MediaContext.searchPerson), isNull);
  });
}
