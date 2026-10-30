import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_geometry.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_row.dart';

MediaItem _item(int index) => MediaItem(
      id: '$index',
      type: MediaType.image,
      createdAt: DateTime(2026, 10, 12),
      width: 100,
      height: 100,
    );

void main() {
  // toolbar, header(day 1), items(4), items(1), header(day 2), items(2)
  final rows = <GalleryRow>[
    const ToolbarRow(),
    DateHeaderRow(day: DateTime(2026, 10, 12), count: 5),
    ItemsRow(items: [for (var i = 0; i < 4; i++) _item(i)], firstIndex: 0),
    ItemsRow(items: [_item(4)], firstIndex: 4),
    DateHeaderRow(day: DateTime(2026, 10, 8), count: 2),
    ItemsRow(items: [_item(5), _item(6)], firstIndex: 5),
  ];
  final geometry = GalleryGeometry(rows: rows, width: 402, columns: 4);

  test('cell size splits the width into columns and gaps', () {
    // (402 - 3 gaps of 2) / 4
    expect(geometry.cellSize, 99);
    expect(geometry.itemsRowExtent, 101);
  });

  test('every row starts where the previous one ends', () {
    expect(geometry.startOf(0), 0);
    expect(geometry.startOf(1), GalleryGeometry.toolbarHeight);
    expect(
      geometry.startOf(2),
      GalleryGeometry.toolbarHeight + GalleryGeometry.headerHeight,
    );
    expect(
      geometry.totalExtent,
      GalleryGeometry.toolbarHeight +
          GalleryGeometry.headerHeight * 2 +
          geometry.itemsRowExtent * 3,
    );
  });

  group('stickyHeaderAt', () {
    test('is null while only the toolbar is visible', () {
      expect(geometry.stickyHeaderAt(-20), isNull);
      expect(geometry.stickyHeaderAt(0), isNull);
      expect(geometry.stickyHeaderAt(GalleryGeometry.toolbarHeight - 1), isNull);
    });

    test('returns the first header once it reaches the top', () {
      final sticky = geometry.stickyHeaderAt(GalleryGeometry.toolbarHeight);

      expect(sticky?.rowIndex, 1);
      expect(sticky?.nextStart, geometry.startOf(4));
    });

    test('moves on to the next header and has no "next" after the last', () {
      final sticky = geometry.stickyHeaderAt(geometry.startOf(4) + 10);

      expect(sticky?.rowIndex, 4);
      expect(sticky?.nextStart, isNull);
    });
  });
}
