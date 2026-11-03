import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/albums/domain/entities/album.dart';
import 'package:proalbums/features/albums/presentation/providers/album_rows_provider.dart';
import 'package:proalbums/features/albums/presentation/providers/albums_providers.dart';
import 'package:proalbums/features/albums/presentation/widgets/album_tile.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_grid.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_grid_skeleton.dart';
import 'package:proalbums/features/gallery/presentation/providers/media_selection.dart';
import 'package:proalbums/shared/widgets/app_back_button.dart';

/// "Select items": choose the pictures / videos of a new album, from all
/// Photos or from inside any album. The pictures are on the SHARED grid in
/// "choose many" mode (checkboxes, drag select, zoom, fast scroll). Returns
/// the chosen items in the order they were picked (Done), or null (back).
class AlbumPickerPage extends ConsumerStatefulWidget {
  const AlbumPickerPage({super.key});

  @override
  ConsumerState<AlbumPickerPage> createState() => _AlbumPickerPageState();
}

class _AlbumPickerPageState extends ConsumerState<AlbumPickerPage> {
  /// ONE selection for the whole page: pictures picked in different albums
  /// add up.
  static final String _scope = MediaScope.picker('select-items');

  final ScrollController _scroll = ScrollController();
  bool _showAlbums = false;
  Album? _openAlbum;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// The picked ids as items. Every picture is in "All", so that list
  /// finds them wherever they were picked.
  Future<void> _done() async {
    final ids = ref.read(mediaSelectionControllerProvider(_scope)).ids;
    final all = await ref.read(albumItemsProvider(kAllAlbumId).future);
    final byId = {for (final item in all) item.id: item};
    if (!mounted) return;
    context.pop(<MediaItem>[for (final id in ids) ?byId[id]]);
  }

  @override
  Widget build(BuildContext context) {
    final inAlbum = _openAlbum != null;
    final count = ref.watch(
      mediaSelectionControllerProvider(_scope).select((s) => s.count),
    );
    final gridAlbumId = _openAlbum?.id ?? kAllAlbumId;

    return MediaScope(
      id: _scope,
      items: albumDisplayItemsProvider(gridAlbumId),
      pickMode: PickMode.multi,
      child: PopScope(
        // Back inside an album goes back to the album list first.
        canPop: !inAlbum,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) setState(() => _openAlbum = null);
        },
        child: Scaffold(
          appBar: AppBar(
            leading: AppBackButton(
              onPressed: () {
                if (inAlbum) {
                  setState(() => _openAlbum = null);
                } else {
                  context.pop();
                }
              },
            ),
            title: Text(
              inAlbum
                  ? _openAlbum!.name
                  : (count == 0 ? 'Select items' : 'Select items ($count)'),
              style: context.textTheme.titleLarge,
            ),
            centerTitle: true,
            actions: [
              TextButton(
                onPressed: count == 0 ? null : _done,
                child: const Text('Done'),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: Column(
            children: [
              if (!inAlbum)
                // A FIXED width, so the toggle never changes size (and never
                // slides) when the selection changes.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Center(
                    child: SizedBox(
                      width: 260,
                      child: SegmentedButton<bool>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: false, label: Text('Photos')),
                          ButtonSegment(value: true, label: Text('Albums')),
                        ],
                        selected: {_showAlbums},
                        onSelectionChanged: (value) =>
                            setState(() => _showAlbums = value.first),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: !inAlbum && _showAlbums
                    ? _albumList()
                    : _grid(gridAlbumId),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _grid(String albumId) {
    final items = ref.watch(albumDisplayItemsProvider(albumId));
    final settings = ref.watch(albumViewSettingsProvider);
    if (items.isEmpty) {
      final loading = ref.watch(albumItemsProvider(albumId)).isLoading;
      return loading
          ? GalleryGridSkeleton(columns: settings.columns)
          : Center(
              child: Text(
                'No photos or videos',
                style: context.textTheme.bodyLarge?.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            );
    }
    final zoom = ref.read(albumViewSettingsProvider.notifier);
    return GalleryGrid(
      // A new grid (from the top) for every album.
      key: ValueKey(albumId),
      controller: _scroll,
      rows: ref.watch(albumGalleryRowsProvider(albumId)),
      items: items,
      columns: settings.columns,
      reversed: false,
      onZoomIn: zoom.zoomIn,
      onZoomOut: zoom.zoomOut,
    );
  }

  Widget _albumList() {
    final sections = ref.watch(albumSectionsProvider);
    return sections.when(
      skipLoadingOnRefresh: true,
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => Center(
        child: Text(
          'Could not load the albums.',
          style: context.textTheme.bodyLarge,
        ),
      ),
      data: (data) {
        // An empty album has nothing to pick from.
        final albums = [
          for (final album in [...data.top, ...data.more, ...data.other])
            if (album.count > 0) album,
        ];
        return GridView.builder(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            MediaQuery.paddingOf(context).bottom + 16,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent:
                (MediaQuery.sizeOf(context).width - 32 - 24) / 3 + 46,
          ),
          itemCount: albums.length,
          itemBuilder: (context, index) {
            final album = albums[index];
            return AlbumTile(
              album: album,
              onTap: () => setState(() => _openAlbum = album),
            );
          },
        );
      },
    );
  }
}
