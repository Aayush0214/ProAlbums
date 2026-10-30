import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_geometry.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_row.dart';

MediaItem _item(int i) => MediaItem(
      id: '$i',
      type: MediaType.image,
      createdAt: DateTime(2026, 10, 12),
      width: 1,
      height: 1,
    );

void main() {
  hitTestTests();

  final rows = <GalleryRow>[
    ItemsRow(items: [for (var i = 0; i < 4; i++) _item(i)], firstIndex: 0),
    ItemsRow(items: [for (var i = 4; i < 8; i++) _item(i)], firstIndex: 4),
    ItemsRow(items: [_item(8), _item(9)], firstIndex: 8),
  ];
  final g = GalleryGeometry(rows: rows, width: 402, columns: 4);
  final reversed = GalleryGeometry(rows: rows, width: 402, columns: 4, reversed: true);

  test('rowIndexAt finds the row covering an offset', () {
    expect(g.rowIndexAt(0), 0);
    expect(g.rowIndexAt(g.itemsRowExtent + 1), 1);
    expect(g.rowIndexAt(99999), 2);
  });

  test('firstItemIndexAt and offsetOfItem are inverse', () {
    expect(g.firstItemIndexAt(g.itemsRowExtent + 5), 4);
    expect(g.offsetOfItem(5), g.itemsRowExtent);
    expect(g.offsetOfItem(9), g.itemsRowExtent * 2);
  });

  test('reversed offsets convert both ways', () {
    const viewport = 300.0;
    final display = reversed.displayOffsetFor(0, viewport);
    // controller offset 0 = bottom of the content
    expect(display, reversed.totalExtent - viewport);
    expect(reversed.controllerOffsetFor(display, viewport), 0);
  });

  test('normal geometry leaves offsets unchanged', () {
    expect(g.displayOffsetFor(120, 300), 120);
    expect(g.controllerOffsetFor(120, 300), 120);
  });
}

void hitTestTests() {
  group('finding the photo under a finger', () {
    final rows = <GalleryRow>[
      const ToolbarRow(),
      DateHeaderRow(day: DateTime(2026, 10, 12), count: 6),
      ItemsRow(items: [for (var i = 0; i < 4; i++) _item(i)], firstIndex: 0),
      ItemsRow(items: [_item(4), _item(5)], firstIndex: 4),
    ];
    final g = GalleryGeometry(rows: rows, width: 402, columns: 4);
    const firstRowTop = GalleryGeometry.toolbarHeight + GalleryGeometry.headerHeight;

    test('toolbar and header are not photos', () {
      expect(g.itemIndexAt(10, 50), isNull);
      expect(g.itemIndexAt(GalleryGeometry.toolbarHeight + 5, 50), isNull);
    });

    test('row and column give the photo index', () {
      expect(g.itemIndexAt(firstRowTop + 5, 5), 0);
      expect(g.itemIndexAt(firstRowTop + 5, 401), 3);
      expect(g.itemIndexAt(firstRowTop + g.itemsRowExtent + 5, 5), 4);
    });

    test('a finger right of the last photo of a short row picks the last one', () {
      expect(g.itemIndexAt(firstRowTop + g.itemsRowExtent + 5, 400), 5);
    });

    test('outside the content gives null', () {
      expect(g.itemIndexAt(-5, 10), isNull);
      expect(g.itemIndexAt(g.totalExtent + 5, 10), isNull);
    });

    test('dateAt gives the day of the header or photos', () {
      expect(g.dateAt(0), DateTime(2026, 10, 12));
      expect(g.dateAt(firstRowTop + 5), DateTime(2026, 10, 12));
    });
  });
}
