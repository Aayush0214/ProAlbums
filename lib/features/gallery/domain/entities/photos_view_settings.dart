import 'dart:math' as math;

import 'package:proalbums/features/gallery/domain/entities/media_group.dart';
import 'package:proalbums/features/gallery/domain/entities/media_page_request.dart';

/// How the user wants the Photos tab to LOOK (not what it contains).
/// Saved on the phone and restored on the next start.
final class PhotosViewSettings {
  const PhotosViewSettings({
    this.columns = defaultColumns,
    this.order = MediaSortOrder.newestFirst,
    this.immersive = false,
  });

  /// The ONLY zoom levels (columns), from biggest photos to the overview:
  /// 3 = zoomed in, 4 = normal (default), 6 = zoomed out, 8 = month overview.
  /// Few, clearly different levels: every step changes the picture a lot, and
  /// we never show hundreds of tiny tiles at once (that made thumbnails slow).
  static const List<int> zoomSteps = [3, 4, 6, 8];
  static const int minColumns = 3;
  static const int maxColumns = 8;
  static const int defaultColumns = 4;

  /// Nearest valid zoom level (old or corrupted saved values, e.g. 5 or 7).
  static int snapToStep(int columns) {
    var best = zoomSteps.first;
    for (final step in zoomSteps) {
      if ((step - columns).abs() < (best - columns).abs()) best = step;
    }
    return best;
  }

  final int columns;

  /// newestFirst = "Newest at the top", oldestFirst = "Newest at the bottom".
  final MediaSortOrder order;

  /// The user's CHOICE of immersive view. Use [showsImmersive] for what is
  /// actually shown.
  final bool immersive;

  /// Next level with bigger photos / smaller photos (stays at the end).
  int get columnsZoomedIn {
    final index = zoomSteps.indexOf(snapToStep(columns));
    return zoomSteps[math.max(0, index - 1)];
  }

  int get columnsZoomedOut {
    final index = zoomSteps.indexOf(snapToStep(columns));
    return zoomSteps[math.min(zoomSteps.length - 1, index + 1)];
  }

  bool get canZoomIn => columns > minColumns;
  bool get canZoomOut => columns < maxColumns;

  /// Smallest zoom: a month overview. It has no browsing-order choice and no
  /// immersive view (so the menu shows only Zoom in + Settings).
  bool get isOverview => columns >= maxColumns;

  bool get showsImmersive => immersive && !isOverview;

  GroupGranularity get granularity =>
      isOverview ? GroupGranularity.month : GroupGranularity.day;

  PhotosViewSettings copyWith({
    int? columns,
    MediaSortOrder? order,
    bool? immersive,
  }) =>
      PhotosViewSettings(
        columns: columns ?? this.columns,
        order: order ?? this.order,
        immersive: immersive ?? this.immersive,
      );

  @override
  bool operator ==(Object other) =>
      other is PhotosViewSettings &&
      other.columns == columns &&
      other.order == order &&
      other.immersive == immersive;

  @override
  int get hashCode => Object.hash(columns, order, immersive);
}
