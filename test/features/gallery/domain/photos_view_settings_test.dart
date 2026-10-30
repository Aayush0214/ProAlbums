import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/features/gallery/domain/entities/media_group.dart';
import 'package:proalbums/features/gallery/domain/entities/photos_view_settings.dart';

void main() {
  zoomStepTests();

  test('default: 4 columns, can zoom both ways, normal view', () {
    const s = PhotosViewSettings();
    expect(s.columns, 4);
    expect(s.canZoomIn, isTrue);
    expect(s.canZoomOut, isTrue);
    expect(s.isOverview, isFalse);
    expect(s.granularity, GroupGranularity.day);
  });

  test('biggest photos: cannot zoom in', () {
    const s = PhotosViewSettings(columns: PhotosViewSettings.minColumns);
    expect(s.canZoomIn, isFalse);
    expect(s.canZoomOut, isTrue);
  });

  test('smallest zoom is the month overview without immersive', () {
    const s = PhotosViewSettings(
      columns: PhotosViewSettings.maxColumns,
      immersive: true,
    );
    expect(s.canZoomOut, isFalse);
    expect(s.isOverview, isTrue);
    expect(s.granularity, GroupGranularity.month);
    // The choice is remembered, but not shown in the overview.
    expect(s.immersive, isTrue);
    expect(s.showsImmersive, isFalse);
  });
}

void zoomStepTests() {
  group('zoom steps (3, 4, 6, 8)', () {
    test('zoom out walks 3 -> 4 -> 6 -> 8 and stops', () {
      var s = const PhotosViewSettings(columns: 3);
      final seen = <int>[s.columns];
      while (s.canZoomOut) {
        s = s.copyWith(columns: s.columnsZoomedOut);
        seen.add(s.columns);
      }
      expect(seen, [3, 4, 6, 8]);
      expect(s.columnsZoomedOut, 8);
    });

    test('zoom in walks back and stops at 3', () {
      const s = PhotosViewSettings(columns: 6);
      expect(s.columnsZoomedIn, 4);
      expect(const PhotosViewSettings(columns: 3).columnsZoomedIn, 3);
    });

    test('old values like 5 or 7 snap to the nearest level', () {
      expect(PhotosViewSettings.snapToStep(5), 4);
      expect(PhotosViewSettings.snapToStep(7), 6);
      expect(PhotosViewSettings.snapToStep(99), 8);
      expect(PhotosViewSettings.snapToStep(0), 3);
    });
  });
}
