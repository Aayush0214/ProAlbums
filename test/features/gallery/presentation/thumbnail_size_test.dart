import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/features/gallery/presentation/grid/thumbnail_size.dart';

void main() {
  test('rounds up to a multiple of 32', () {
    expect(thumbnailSizeFor(cellSize: 270, devicePixelRatio: 1), 288);
    expect(thumbnailSizeFor(cellSize: 100, devicePixelRatio: 2.75), 288);
  });

  test('similar cell sizes ask for the same size (cache friendly)', () {
    expect(
      thumbnailSizeFor(cellSize: 269.4, devicePixelRatio: 1),
      thumbnailSizeFor(cellSize: 270.6, devicePixelRatio: 1),
    );
  });

  test('is limited to a sensible range', () {
    expect(thumbnailSizeFor(cellSize: 20, devicePixelRatio: 1), 96);
    expect(thumbnailSizeFor(cellSize: 400, devicePixelRatio: 3), 512);
  });
}
