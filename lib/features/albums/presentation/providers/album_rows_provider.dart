import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proalbums/features/albums/presentation/providers/albums_providers.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_row.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_rows_builder.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'album_rows_provider.g.dart';

/// One album's pictures as rows for the shared GalleryGrid. Recomputed only
/// when the album's pictures or the zoom level change, never while scrolling.
///
/// "Newest at the bottom" is already in the item order (see
/// albumDisplayItems), so the rows are always cut from the start.
@riverpod
List<GalleryRow> albumGalleryRows(Ref ref, String albumId) {
  final items = ref.watch(albumDisplayItemsProvider(albumId));
  final columns = ref.watch(albumViewSettingsProvider.select((s) => s.columns));
  return GalleryRowsBuilder.buildFlat(
    items: items,
    columns: columns,
    alignToEnd: false,
  );
}
