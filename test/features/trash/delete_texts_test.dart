import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/trash/presentation/widgets/delete_texts.dart';

MediaItem _item(String id, MediaType type) => MediaItem(
      id: id,
      type: type,
      createdAt: DateTime(2026, 10, 12),
      width: 1,
      height: 1,
    );

void main() {
  group('to the trash (setting on)', () {
    test('one photo', () {
      final t = deleteDialogTexts([_item('1', MediaType.image)]);
      expect(t.title, 'Delete this image?');
      expect(t.message, contains('This image will be deleted from all albums'));
      expect(t.message, contains('"Recently deleted"'));
    });

    test('one video', () {
      final t = deleteDialogTexts([_item('1', MediaType.video)]);
      expect(t.title, 'Delete this video?');
      expect(t.message, contains('This video'));
    });

    test('several items show the count, whatever their type', () {
      final t = deleteDialogTexts([
        for (var i = 0; i < 4; i++)
          _item('$i', i.isEven ? MediaType.image : MediaType.video),
      ]);
      expect(t.title, 'Delete 4 items?');
      expect(t.message, startsWith('Any selected item'));
    });
  });

  group('for good (setting off)', () {
    test('never mentions "Recently deleted"', () {
      final one = deleteDialogTexts([_item('1', MediaType.image)], toTrash: false);
      final many = deleteDialogTexts(
        [_item('1', MediaType.image), _item('2', MediaType.video)],
        toTrash: false,
      );
      for (final t in [one, many]) {
        expect(t.message, isNot(contains('Recently deleted')));
        expect(t.message, contains('permanently'));
      }
    });
  });
}
