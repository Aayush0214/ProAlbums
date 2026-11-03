import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/albums/presentation/providers/album_rows_provider.dart';
import 'package:proalbums/features/albums/presentation/providers/albums_providers.dart';
import 'package:proalbums/features/gallery/presentation/actions/media_actions.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_grid.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_grid_skeleton.dart';
import 'package:proalbums/features/gallery/presentation/providers/media_selection.dart';

/// "Change cover": the pictures of ONE album on the shared grid (zoom, fast
/// scroll...); tapping one chooses it. Returns the chosen picture's id
/// (null = back).
class ChangeCoverPage extends ConsumerStatefulWidget {
  const ChangeCoverPage({required this.albumId, super.key});

  final String albumId;

  @override
  ConsumerState<ChangeCoverPage> createState() => _ChangeCoverPageState();
}

class _ChangeCoverPageState extends ConsumerState<ChangeCoverPage> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final albumId = widget.albumId;
    final items = ref.watch(albumDisplayItemsProvider(albumId));
    final settings = ref.watch(albumViewSettingsProvider);
    final zoom = ref.read(albumViewSettingsProvider.notifier);

    return MediaScope(
      id: MediaScope.picker('cover:$albumId'),
      mediaContext: MediaContext.album,
      items: albumDisplayItemsProvider(albumId),
      albumId: albumId,
      pickMode: PickMode.single,
      onPick: (item) => context.pop(item.id),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Choose cover', style: context.textTheme.titleLarge),
          centerTitle: true,
        ),
        body: items.isEmpty && ref.watch(albumItemsProvider(albumId)).isLoading
            ? GalleryGridSkeleton(columns: settings.columns)
            : items.isEmpty
            ? const SizedBox.shrink()
            : GalleryGrid(
                controller: _scroll,
                rows: ref.watch(albumGalleryRowsProvider(albumId)),
                items: items,
                columns: settings.columns,
                reversed: false,
                onZoomIn: zoom.zoomIn,
                onZoomOut: zoom.zoomOut,
              ),
      ),
    );
  }
}
