import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_geometry.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_row.dart';

// Only the row COUNT matters for these tests, so the rows hold no items.
GalleryGeometry _geometry({GridOrigin? origin, bool reversed = false}) {
  final rows = <GalleryRow>[
    const ItemsRow(items: <MediaItem>[], firstIndex: 0),
    const ItemsRow(items: <MediaItem>[], firstIndex: 3),
    const ItemsRow(items: <MediaItem>[], firstIndex: 6),
  ];
  return GalleryGeometry(
    rows: rows,
    width: 302, // 3 columns, gap 2 -> cell 99.33
    columns: 3,
    reversed: reversed,
    origin: origin,
  );
}

void main() {
  test('without an origin nothing changes', () {
    final geometry = _geometry();
    expect(geometry.displayOffsetFor(120, 800), 120);
    expect(geometry.controllerOffsetFor(120, 800), 120);
    expect(geometry.hasHeaders, isFalse);
  });

  test('an origin (album app bar) shifts the offsets both ways', () {
    final origin = GridOrigin()..extent = 150;
    final geometry = _geometry(origin: origin);

    // Scrolled 200: the first row starts 50 px above the top.
    expect(geometry.displayOffsetFor(200, 800), 50);
    // Still inside the app bar: negative, so nothing is hit / sticky yet.
    expect(geometry.displayOffsetFor(100, 800), -50);
    expect(geometry.controllerOffsetFor(50, 800), 200);
  });

  test('the origin can change after the geometry was built', () {
    final origin = GridOrigin();
    final geometry = _geometry(origin: origin);
    expect(geometry.displayOffsetFor(200, 800), 200);

    origin.extent = 80; // the app bar was measured
    expect(geometry.displayOffsetFor(200, 800), 120);
  });

  test('a touch below the app bar lands inside the first row', () {
    final origin = GridOrigin()..extent = 150;
    final geometry = _geometry(origin: origin);

    // Not scrolled: viewport y 160 is 10 px into the first row, y 100 is
    // still the app bar (negative = not on any row).
    expect(geometry.displayOffsetFor(0, 800) + 160, 10);
    expect(geometry.displayOffsetFor(0, 800) + 100, lessThan(0));
    expect(geometry.rowIndexAt(10), 0);
    expect(geometry.rowIndexAt(10 + geometry.itemsRowExtent), 1);
  });
}
