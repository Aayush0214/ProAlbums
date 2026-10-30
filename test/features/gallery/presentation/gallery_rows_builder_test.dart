import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/features/gallery/domain/entities/media_group.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_row.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_rows_builder.dart';

MediaItem _item(int index) => MediaItem(
      id: '$index',
      type: MediaType.image,
      createdAt: DateTime(2026, 10, 12),
      width: 100,
      height: 100,
    );

MediaGroup _group(DateTime day, int from, int count) => MediaGroup(
      day: day,
      items: [for (var i = from; i < from + count; i++) _item(i)],
    );

void main() {
  test('an empty library has only the toolbar row', () {
    final rows = GalleryRowsBuilder.build(groups: const [], columns: 4);

    expect(rows.length, 1);
    expect(rows.first, isA<ToolbarRow>());
  });

  test('builds toolbar, header and rows of at most `columns` items', () {
    final rows = GalleryRowsBuilder.build(
      groups: [
        _group(DateTime(2026, 10, 12), 0, 6), // 4 + 2
        _group(DateTime(2026, 10, 8), 6, 4), // 4
      ],
      columns: 4,
    );

    expect(rows.map((r) => r.runtimeType), [
      ToolbarRow,
      DateHeaderRow,
      ItemsRow,
      ItemsRow,
      DateHeaderRow,
      ItemsRow,
    ]);

    final first = rows[2] as ItemsRow;
    final second = rows[3] as ItemsRow;
    final third = rows[5] as ItemsRow;
    expect(first.items.length, 4);
    expect(second.items.length, 2);
    expect(third.items.length, 4);

    // firstIndex = position in the flat, ungrouped list
    expect(first.firstIndex, 0);
    expect(second.firstIndex, 4);
    expect(third.firstIndex, 6);

    expect((rows[1] as DateHeaderRow).count, 6);
  });

  test('the column count changes the row split', () {
    final rows = GalleryRowsBuilder.build(
      groups: [_group(DateTime(2026, 10, 12), 0, 6)],
      columns: 3,
    );

    expect(rows.whereType<ItemsRow>().length, 2);
  });
}
