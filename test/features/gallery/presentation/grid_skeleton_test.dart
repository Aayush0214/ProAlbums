import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_geometry.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_grid_skeleton.dart';

void main() {
  test('tiles fill the space, same size and gap as the real grid', () {
    const columns = 4;
    const size = Size(403, 500);
    final boxes = gridSkeletonBoxes(size, columns);
    const gap = GalleryGeometry.gap;
    const cell = (403 - gap * 3) / 4;

    expect(boxes.first.outerRect, const Rect.fromLTWH(0, 0, cell, cell));
    expect(boxes[1].left, cell + gap);
    // 500 / (cell + gap) -> 5 rows (the last one cut by the edge).
    expect(boxes, hasLength(5 * columns));
    expect(boxes.last.right, closeTo(403, 1e-9));
  });

  test('no space: no boxes', () {
    expect(gridSkeletonBoxes(Size.zero, 4), isEmpty);
  });
}
