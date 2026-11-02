import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/albums/domain/entities/album.dart';
import 'package:proalbums/features/albums/presentation/providers/albums_providers.dart';
import 'package:proalbums/features/albums/presentation/widgets/album_tile.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/providers/photos_selection_controller.dart';
import 'package:proalbums/features/gallery/presentation/widgets/media_thumbnail.dart';
import 'package:proalbums/features/gallery/presentation/widgets/selection_checkbox.dart';

/// "Select items": choose the pictures / videos of a new album, from all
/// Photos or from inside any album. Returns the chosen items (Done), or null
/// (back).
class AlbumPickerPage extends ConsumerStatefulWidget {
  const AlbumPickerPage({super.key});

  @override
  ConsumerState<AlbumPickerPage> createState() => _AlbumPickerPageState();
}

class _AlbumPickerPageState extends ConsumerState<AlbumPickerPage> {
  static const double _gap = 1;
  static const int _columns = 4;

  // Keeps the order in which the items were picked.
  final Map<String, MediaItem> _selected = {};
  bool _showAlbums = false;
  Album? _openAlbum;

  void _toggle(MediaItem item) {
    setState(() {
      if (_selected.remove(item.id) == null) _selected[item.id] = item;
    });
  }

  @override
  Widget build(BuildContext context) {
    final inAlbum = _openAlbum != null;
    final count = _selected.length;

    return PopScope(
      // Back inside an album goes back to the album list first.
      canPop: !inAlbum,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) setState(() => _openAlbum = null);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(
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
              onPressed: count == 0
                  ? null
                  : () => context.pop(_selected.values.toList(growable: false)),
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
              child: inAlbum
                  ? _grid(_openAlbum!.id)
                  : (_showAlbums ? _albumList() : _grid(kAllAlbumId)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _grid(String albumId) {
    final items = ref.watch(albumItemsProvider(albumId));
    return items.when(
      skipLoadingOnRefresh: true,
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => Center(
        child: Text(
          'Could not load the photos.',
          style: context.textTheme.bodyLarge,
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return Center(
            child: Text(
              'No photos or videos',
              style: context.textTheme.bodyLarge
                  ?.copyWith(color: context.colors.textSecondary),
            ),
          );
        }
        final width = MediaQuery.sizeOf(context).width;
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final cell = (width - _gap * (_columns - 1)) / _columns;
        final thumb = math.max(128, (cell * dpr / 64).ceil() * 64);

        return GridView.builder(
          padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _columns,
            mainAxisSpacing: _gap,
            crossAxisSpacing: _gap,
          ),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final item = list[index];
            final picked = _selected.containsKey(item.id);
            return GestureDetector(
              key: ValueKey(item.id),
              onTap: () => _toggle(item),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MediaThumbnail(item: item, size: thumb),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: SelectionCheckbox(
                      state: picked ? SelectionState.all : SelectionState.none,
                      size: 20,
                      onPhoto: true,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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
            mainAxisExtent: (MediaQuery.sizeOf(context).width - 32 - 24) / 3 + 46,
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
