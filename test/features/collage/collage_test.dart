import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/features/collage/domain/collage_layout.dart';
import 'package:proalbums/features/collage/domain/collage_rules.dart';
import 'package:proalbums/features/collage/presentation/collage_canvas.dart';
import 'package:proalbums/features/gallery/presentation/actions/media_actions.dart';

void main() {
  group('layouts depend on how many pictures there are', () {
    for (var count = 2; count <= 9; count++) {
      test('$count pictures: several layouts, each uses every picture once '
          'and fills the collage', () {
        final layouts = collageLayoutsFor(count);
        expect(layouts.length, greaterThanOrEqualTo(2));
        for (final layout in layouts) {
          final rects = collageCellRects(layout);
          expect(rects.keys.toSet(), {for (var i = 0; i < count; i++) i});
          final area = rects.values.fold<double>(
            0,
            (sum, r) => sum + r.width * r.height,
          );
          expect(area, closeTo(1, 1e-9));
        }
      });
    }

    test('no layouts for fewer than 2 pictures', () {
      expect(collageLayoutsFor(1), isEmpty);
    });
  });

  group('dragging the line between cells', () {
    final twoSideBySide = collageLayoutsFor(2)
        .firstWhere((layout) => layout is CollageSplit && layout.sideBySide);

    test('gives one side more room', () {
      final moved = moveCollageDivider(twoSideBySide, const [], 0.2);
      final rects = collageCellRects(moved);
      expect(rects[0]!.width, closeTo(0.7, 1e-9));
      expect(rects[1]!.width, closeTo(0.3, 1e-9));
    });

    test('never makes a cell smaller than the minimum', () {
      final moved = moveCollageDivider(twoSideBySide, const [], 5);
      expect(collageCellRects(moved)[1]!.width, closeTo(minCollageRatio, 1e-9));
    });

    test('every line can be found', () {
      for (final layout in collageLayoutsFor(5)) {
        // n cells = n - 1 splits.
        expect(collageDividers(layout), hasLength(4));
      }
    });
  });

  group('a picture always covers its cell', () {
    test('wide picture in a tall cell, zoomed and moved too far', () {
      const box = Size(100, 200);
      final rect = coverRect(
        box: box,
        aspect: 16 / 9,
        scale: 1.5,
        offset: const Offset(5, -5),
      );
      expect(rect.left, lessThanOrEqualTo(0));
      expect(rect.top, lessThanOrEqualTo(0));
      expect(rect.right, greaterThanOrEqualTo(box.width));
      expect(rect.bottom, greaterThanOrEqualTo(box.height));
      expect(rect.width / rect.height, closeTo(16 / 9, 1e-9));
    });
  });

  group('zoom out and the grey-cell bug', () {
    test('zooming out down to the whole picture (no further)', () {
      const box = Size(100, 200);
      const aspect = 16 / 9;
      final whole = coverRect(
        box: box,
        aspect: aspect,
        scale: 0.01,
        offset: Offset.zero,
      );
      expect(whole.width, closeTo(box.width, 1e-9));
      expect(whole.height, closeTo(box.width / aspect, 1e-9));
      expect(
        minPictureScale(box, aspect),
        closeTo(whole.width / (box.height * aspect), 1e-9),
      );
    });

    test('a picture exactly the cell shape never throws (rounding)', () {
      // Sizes that made (picture - cell) / 2 a tiny negative number before.
      for (final width in [97.3, 123.45, 333.333, 0.1 + 0.2]) {
        expect(
          () => coverRect(
            box: Size(width, width * 3 / 7),
            aspect: 7 / 3,
            scale: 1,
            offset: const Offset(0.4, -0.4),
          ),
          returnsNormally,
        );
      }
    });

    test('an empty cell (while a layout changes) is not an error', () {
      expect(
        coverRect(box: Size.zero, aspect: 1, scale: 1, offset: Offset.zero),
        Rect.zero,
      );
    });
  });

  group('the Collage button (selection bar)', () {
    bool on({required int count, bool image = true, bool video = false}) =>
        isActionEnabled(
          MediaAction.collage,
          hasImage: image,
          hasVideo: video,
          count: count,
        );

    test('2 or more pictures: on', () {
      expect(on(count: 2), isTrue);
      expect(on(count: 9), isTrue);
      // More than 9 is still on: pressing it says "Select up to 9".
      expect(on(count: 12), isTrue);
    });

    test('one picture, or any video: off', () {
      expect(on(count: 1), isFalse);
      expect(on(count: 3, video: true), isFalse);
      expect(on(count: 3, image: false, video: true), isFalse);
    });

    test('the same rule as the collage feature', () {
      expect(canMakeCollage(count: 1, hasVideo: false), isFalse);
      expect(canMakeCollage(count: 4, hasVideo: true), isFalse);
      expect(canMakeCollage(count: 4, hasVideo: false), isTrue);
    });
  });

  test('Free layout starts with every picture on the collage', () {
    final free = freeStartFor(7);
    expect(free.map((p) => p.slot), [0, 1, 2, 3, 4, 5, 6]);
    for (final picture in free) {
      expect(picture.center.dx, inInclusiveRange(0, 1));
      expect(picture.center.dy, inInclusiveRange(0, 1));
    }
  });
}
