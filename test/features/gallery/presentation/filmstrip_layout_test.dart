import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/features/gallery/presentation/viewer/filmstrip_layout.dart';
import 'package:proalbums/features/gallery/presentation/viewer/video_math.dart';
import 'package:proalbums/features/gallery/presentation/viewer/viewer_math.dart';

void main() {
  group('without an open video', () {
    const layout = FilmstripLayout(itemCount: 20);

    test('one cell per item, each one slot wide', () {
      expect(layout.cellCount, 20);
      expect(layout.extentOfCell(3), kFilmstripSlot);
      expect(layout.cellAt(7), (item: 7, frame: null));
    });

    test('index and offset match', () {
      expect(layout.offsetForIndex(0), 0);
      expect(layout.offsetForIndex(5), 5 * kFilmstripSlot);
      expect(layout.pointAt(layout.offsetForIndex(7)).index, 7);
    });

    test('a position between two items picks the nearer one', () {
      expect(layout.pointAt(kFilmstripSlot * 3 + 5).index, 3);
      expect(layout.pointAt(kFilmstripSlot * 3 + 25).index, 4);
    });

    test('never outside the list', () {
      expect(layout.pointAt(-100).index, 0);
      expect(layout.pointAt(99999).index, 19);
      expect(const FilmstripLayout(itemCount: 0).pointAt(50).index, 0);
    });
  });

  group('with an open video', () {
    // item 5 is the open video, 10 frames wide
    const layout = FilmstripLayout(itemCount: 20, videoIndex: 5, frameCount: 10);
    const videoWidth = 10 * kVideoFrameWidth;

    test('the video takes the place of its item', () {
      expect(layout.cellCount, 20 - 1 + 10);
      expect(layout.cellAt(4), (item: 4, frame: null));
      expect(layout.cellAt(5), (item: null, frame: 0));
      expect(layout.cellAt(14), (item: null, frame: 9));
      expect(layout.cellAt(15), (item: 6, frame: null));
      expect(layout.extentOfCell(5), kVideoFrameWidth);
      expect(layout.extentOfCell(15), kFilmstripSlot);
    });

    test('items after the video are pushed by its width', () {
      expect(layout.startOfItem(4), 4 * kFilmstripSlot);
      expect(layout.startOfItem(6), 5 * kFilmstripSlot + videoWidth);
    });

    test('start and end of the video', () {
      final start = layout.pointAt(layout.offsetForVideoFraction(0));
      expect(start.index, 5);
      expect(start.videoFraction, closeTo(0, 1e-9));

      final end = layout.pointAt(layout.offsetForVideoFraction(1));
      expect(end.index, 5);
      expect(end.videoFraction, closeTo(1, 1e-9));
    });

    test('a moment of the video and its offset undo each other', () {
      final point = layout.pointAt(layout.offsetForVideoFraction(0.4));
      expect(point.videoFraction, closeTo(0.4, 1e-9));
    });

    test('left and right of the video are other items', () {
      final left = layout.pointAt(layout.offsetForIndex(3));
      expect(left.index, 3);
      expect(left.videoFraction, isNull);

      final right = layout.pointAt(layout.offsetForIndex(8));
      expect(right.index, 8);
      expect(right.videoFraction, isNull);
    });

    test('the last item is still reachable', () {
      expect(layout.pointAt(layout.offsetForIndex(19)).index, 19);
      expect(layout.pointAt(999999).index, 19);
    });
  });
}
