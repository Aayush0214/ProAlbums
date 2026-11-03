import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proalbums/features/gallery/domain/entities/media_group.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/domain/entities/media_page_request.dart';
import 'package:proalbums/features/gallery/domain/entities/photos_view_settings.dart';
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

/// The photos cut into days (or months for the overview). Kept between
/// zooms: grouping 2600+ photos is part of what a zoom used to redo.
@riverpod
List<MediaGroup> photosGroups(Ref ref, GroupGranularity granularity) {
  ref.keepAlive();
  return MediaGrouper.group(ref.watch(photosDisplayItemsProvider), granularity);
}

/// The rows of ONE zoom level. Kept, so going back to a zoom level costs
/// nothing; recomputed (lazily) only when the photos change.
@riverpod
List<GalleryRow> photosRowsFor(
  Ref ref, {
  required int columns,
  required bool flat,
  required bool alignToEnd,
}) {
  ref.keepAlive();
  final items = ref.watch(photosDisplayItemsProvider);
  if (flat) {
    return GalleryRowsBuilder.buildFlat(
      items: items,
      columns: columns,
      alignToEnd: alignToEnd,
    );
  }
  final granularity = PhotosViewSettings(columns: columns).granularity;
  return GalleryRowsBuilder.build(
    groups: ref.watch(photosGroupsProvider(granularity)),
    columns: columns,
  );
}

/// items + settings -> flat rows for the current zoom level. Recomputed ONLY
/// when the items or a view setting change (never while just scrolling).
///
/// A zoom used to group and cut all photos inside the zoom frame (~5 ms of
/// it in the CPU profile). Now the other zoom levels are prepared a moment
/// later, when the app is idle, so a zoom just picks the ready rows.
@riverpod
List<GalleryRow> galleryRows(Ref ref) {
  final settings = ref.watch(photosViewSettingsControllerProvider);
  final hasItems = ref.watch(
    photosDisplayItemsProvider.select((items) => items.isNotEmpty),
  );

  ProviderListenable<List<GalleryRow>> rowsFor(int columns) {
    final zoomed = settings.copyWith(columns: columns);
    // Same rule as photosImmersiveActive (overview is never immersive).
    final flat = zoomed.showsImmersive && hasItems;
    return photosRowsForProvider(
      columns: columns,
      flat: flat,
      alignToEnd: flat && zoomed.order == MediaSortOrder.oldestFirst,
    );
  }

  final rows = ref.watch(rowsFor(settings.columns));
  _prepareLater(ref, [
    for (final columns in PhotosViewSettings.zoomSteps)
      if (columns != settings.columns) rowsFor(columns),
  ]);
  return rows;
}

/// Builds [providers] one by one when the app is idle (not while scrolling
/// or animating), a moment after the rows changed.
void _prepareLater(Ref ref, List<ProviderListenable<Object?>> providers) {
  final timer = Timer(const Duration(milliseconds: 600), () {
    for (final provider in providers) {
      SchedulerBinding.instance.scheduleTask<void>(
        () {
          if (ref.mounted) ref.read(provider);
        },
        Priority.idle,
      );
    }
  });
  ref.onDispose(timer.cancel);
}
