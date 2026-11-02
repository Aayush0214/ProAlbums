import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/features/gallery/data/repositories/photo_manager_media_image_repository.dart';
import 'package:proalbums/features/gallery/presentation/viewer/viewer_math.dart';

void main() {
  group('viewerImageLongEdge', () {
    test('rounds up to a multiple of 128', () {
      expect(viewerImageLongEdge(2400), 2432);
    });

    test('is limited to 1080..2560', () {
      expect(viewerImageLongEdge(800), 1080);
      expect(viewerImageLongEdge(4000), 2560);
    });

    test('similar screens ask for the same size (cache friendly)', () {
      expect(viewerImageLongEdge(2390), viewerImageLongEdge(2400));
    });
  });

  group('resolveViewerIndex', () {
    const ids = ['a', 'b', 'c', 'd'];

    test('the same photo is kept when new photos are added before it', () {
      expect(
        resolveViewerIndex(ids: ['x', 'y', ...ids], currentId: 'c', lastIndex: 2),
        4,
      );
    });

    test('a deleted photo stays near the old position', () {
      expect(
        resolveViewerIndex(ids: ['a', 'b', 'd'], currentId: 'c', lastIndex: 2),
        2,
      );
    });

    test('a deleted LAST photo moves to the new last one', () {
      expect(
        resolveViewerIndex(ids: ['a', 'b'], currentId: 'd', lastIndex: 3),
        1,
      );
    });

    test('an empty list gives -1', () {
      expect(resolveViewerIndex(ids: [], currentId: 'a', lastIndex: 0), -1);
    });
  });

  group('displaySizeFor', () {
    test('big photo is scaled down and keeps its shape', () {
      final size = displaySizeFor(width: 4000, height: 3000, maxLongEdge: 2000);
      expect(size.width, 2000);
      expect(size.height, 1500);
    });

    test('portrait photo: the HEIGHT is the longer side', () {
      final size = displaySizeFor(width: 3000, height: 4000, maxLongEdge: 2000);
      expect(size.width, 1500);
      expect(size.height, 2000);
    });

    test('a small photo is never enlarged', () {
      final size = displaySizeFor(width: 800, height: 600, maxLongEdge: 2000);
      expect(size.width, 800);
      expect(size.height, 600);
    });

    test('unknown size asks for a square', () {
      final size = displaySizeFor(width: 0, height: 0, maxLongEdge: 1500);
      expect(size.width, 1500);
      expect(size.height, 1500);
    });
  });
}
