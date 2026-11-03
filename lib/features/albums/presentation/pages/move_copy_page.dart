import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/albums/domain/entities/album.dart';
import 'package:proalbums/features/albums/domain/entities/transfer_target.dart';
import 'package:proalbums/features/albums/domain/services/transfer_destinations.dart';
import 'package:proalbums/features/albums/presentation/providers/albums_providers.dart';
import 'package:proalbums/features/albums/presentation/widgets/new_album_flow.dart';
import 'package:proalbums/features/albums/presentation/widgets/transfer_flow.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/grid/thumbnail_size.dart';
import 'package:proalbums/features/gallery/presentation/widgets/media_thumbnail.dart';
import 'package:proalbums/shared/widgets/app_snack_bar.dart';
import 'package:proalbums/shared/widgets/shimmer_skeleton.dart';

/// "Move/Copy": where the selected pictures / videos should go. The first
/// row makes a new album; the others are the albums that are real folders.
/// Tapping one asks Copy or Move, does it, and closes with `true` (so the
/// caller leaves select mode). Closing with X returns `false`.
class MoveCopyPage extends ConsumerStatefulWidget {
  const MoveCopyPage({
    required this.items,
    this.fromAlbumId,
    super.key,
  });

  /// What to copy / move.
  final List<MediaItem> items;

  /// The album the items are taken from: not offered as a target.
  final String? fromAlbumId;

  @override
  ConsumerState<MoveCopyPage> createState() => _MoveCopyPageState();
}

class _MoveCopyPageState extends ConsumerState<MoveCopyPage> {
  static const double _thumbSize = 56;

  /// A dialog or the copy is running: ignore more taps.
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Opened without items (e.g. the app was restored on this page): there
    // is nothing to do here.
    if (widget.items.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.pop(false);
      });
    }
  }

  void _say(String text) => showAppSnackBar(context, text);

  Future<void> _guard(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _newAlbum() => _guard(() async {
        final name = await createNewAlbum(context, ref, say: _say);
        if (name == null || !mounted) return;
        await _transferTo(TransferTarget.newFolder(name));
      });

  Future<void> _album(Album album) =>
      _guard(() => _transferTo(TransferTarget.of(album)));

  Future<void> _transferTo(TransferTarget target) async {
    final method = await showTransferMethodDialog(context);
    if (method == null || !mounted) return;

    final result = await runTransfer(
      context,
      ref,
      items: widget.items,
      target: target,
      method: method,
    );
    if (!mounted) return;
    final text = transferMessage(
      method: method,
      albumName: target.name,
      result: result,
    );
    if (text != null) _say(text);
    // Done: back to the grid. Failed or cancelled: stay, pick again.
    if (result != null && result.done > 0) context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final sections = ref.watch(albumSectionsProvider);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final thumb = thumbnailSizeFor(cellSize: _thumbSize, devicePixelRatio: dpr);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(LucideIcons.x),
          onPressed: () => context.pop(false),
        ),
        title: Text('Move/Copy', style: context.textTheme.titleLarge),
        centerTitle: true,
      ),
      body: sections.when(
        skipLoadingOnRefresh: true,
        loading: () => const _DestinationsSkeleton(size: _thumbSize),
        error: (error, stackTrace) => Center(
          child: Text(
            'Could not load the albums.',
            style: context.textTheme.bodyLarge,
          ),
        ),
        data: (data) {
          final albums = transferDestinations(
            data,
            excludeAlbumId: widget.fromAlbumId,
          );
          return ListView.builder(
            padding: EdgeInsets.only(
              top: 4,
              bottom: MediaQuery.paddingOf(context).bottom + 16,
            ),
            itemCount: albums.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _DestinationRow(
                  label: 'New album',
                  size: _thumbSize,
                  onTap: _newAlbum,
                  picture: const _PlaceholderBox(icon: LucideIcons.plus),
                );
              }
              final album = albums[index - 1];
              final cover = album.cover;
              return _DestinationRow(
                key: ValueKey(album.id),
                label: album.name,
                size: _thumbSize,
                onTap: () => _album(album),
                picture: cover == null
                    ? const _PlaceholderBox(icon: LucideIcons.image)
                    : MediaThumbnail(item: cover, size: thumb),
              );
            },
          );
        },
      ),
    );
  }
}

/// One row: rounded picture + name.
class _DestinationRow extends StatelessWidget {
  const _DestinationRow({
    required this.label,
    required this.size,
    required this.onTap,
    required this.picture,
    super.key,
  });

  final String label;
  final double size;
  final VoidCallback onTap;
  final Widget picture;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox.square(dimension: size, child: picture),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The grey square of "New album" and of an album without pictures.
class _PlaceholderBox extends StatelessWidget {
  const _PlaceholderBox({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.colorScheme.surfaceContainerHigh,
      child: Icon(icon, color: context.colors.textSecondary),
    );
  }
}

/// Shimmering rows in the shape of the list while the albums load.
class _DestinationsSkeleton extends StatelessWidget {
  const _DestinationsSkeleton({required this.size});

  /// The picture's side (same as a real row).
  final double size;

  @override
  Widget build(BuildContext context) {
    // A row: 8 + picture + 8, starting below the list's 4 px top padding.
    final rowHeight = size + 16;
    return ShimmerSkeleton(
      layout: (box) => [
        for (var y = 4.0; y < box.height; y += rowHeight) ...[
          RRect.fromRectAndRadius(
            Rect.fromLTWH(16, y + 8, size, size),
            const Radius.circular(12),
          ),
          RRect.fromRectAndRadius(
            Rect.fromLTWH(16 + size + 16, y + 8 + (size - 14) / 2, 120, 14),
            const Radius.circular(4),
          ),
        ],
      ],
    );
  }
}
