import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/domain/entities/media_page_request.dart';
import 'package:proalbums/features/gallery/domain/services/media_grouper.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_row.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_rows_builder.dart';
import 'package:proalbums/features/gallery/presentation/providers/photos_controller.dart';
import 'package:proalbums/features/gallery/presentation/providers/photos_view_settings_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'gallery_rows_provider.g.dart';

/// The photos in the order the user SEES them (and the viewer will page
/// through them). Loaded newest first; reversed for "Newest at the bottom".
@riverpod
List<MediaItem> photosDisplayItems(Ref ref) {
  final items = ref.watch(
        photosControllerProvider.select((value) => value.value?.items),
      ) ??
      const <MediaItem>[];
  final order = ref.watch(
    photosViewSettingsControllerProvider.select((settings) => settings.order),
  );

  return order == MediaSortOrder.newestFirst
      ? items
      : items.reversed.toList(growable: false);
}

/// Is the immersive view really on screen? (An empty library keeps the normal
/// view, so the filter chips stay reachable.)
@riverpod
bool photosImmersiveActive(Ref ref) {
  final wanted = ref.watch(
    photosViewSettingsControllerProvider
        .select((settings) => settings.showsImmersive),
  );
  final hasItems = ref.watch(
    photosDisplayItemsProvider.select((items) => items.isNotEmpty),
  );
  return wanted && hasItems;
}

/// items + settings -> flat rows. Recomputed ONLY when the items or a view
/// setting change (never while just scrolling).
@riverpod
List<GalleryRow> galleryRows(Ref ref) {
  final items = ref.watch(photosDisplayItemsProvider);
  final settings = ref.watch(photosViewSettingsControllerProvider);
  final immersive = ref.watch(photosImmersiveActiveProvider);

  if (immersive) {
    return GalleryRowsBuilder.buildFlat(
      items: items,
      columns: settings.columns,
      alignToEnd: settings.order == MediaSortOrder.oldestFirst,
    );
  }
  return GalleryRowsBuilder.build(
    groups: MediaGrouper.group(items, settings.granularity),
    columns: settings.columns,
  );
}
