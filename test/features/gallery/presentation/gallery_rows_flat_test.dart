import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_row.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_rows_builder.dart';

List<MediaItem> _items(int n) => [
      for (var i = 0; i < n; i++)
        MediaItem(
          id: '$i',
          type: MediaType.image,
          createdAt: DateTime(2026, 10, 1).add(Duration(hours: i)),
          width: 1,
          height: 1,
        ),
    ];

void main() {
  test('flat rows have no toolbar and no headers', () {
    final rows = GalleryRowsBuilder.buildFlat(
      items: _items(10),
      columns: 4,
      alignToEnd: false,
    );

    expect(rows.every((r) => r is ItemsRow), isTrue);
    expect(rows.map((r) => (r as ItemsRow).items.length), [4, 4, 2]);
  });

  test('aligned to the end: the SHORT row is the first one', () {
    final rows = GalleryRowsBuilder.buildFlat(
      items: _items(10),
      columns: 4,
      alignToEnd: true,
    );

    expect(rows.map((r) => (r as ItemsRow).items.length), [2, 4, 4]);
    expect((rows.first as ItemsRow).firstIndex, 0);
    expect((rows.last as ItemsRow).items.last.id, '9');
  });
}
