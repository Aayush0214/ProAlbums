import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/error/failures.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/gallery/domain/entities/media_page_request.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_geometry.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_grid.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_grid_skeleton.dart';
import 'package:proalbums/features/gallery/presentation/providers/gallery_rows_provider.dart';
import 'package:proalbums/features/gallery/presentation/providers/photos_controller.dart';
import 'package:proalbums/features/gallery/presentation/providers/photos_query_controller.dart';
import 'package:proalbums/features/gallery/presentation/providers/photos_view_settings_controller.dart';
import 'package:proalbums/features/gallery/presentation/widgets/gallery_toolbar.dart';

/// The scrolling part of the Photos tab. The grid itself is the shared
/// [GalleryGrid] (the same one every album uses); this widget only supplies
/// the Photos data and the empty / error / loading states.
class PhotosBody extends ConsumerStatefulWidget {
  const PhotosBody({required this.appBarExtent, super.key});

  /// Height of status bar + app bar (where the immersive date label goes under).
  final double appBarExtent;

  @override
  ConsumerState<PhotosBody> createState() => _PhotosBodyState();
}

class _PhotosBodyState extends ConsumerState<PhotosBody> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A different filter shows different photos: start from the beginning.
    // (Zoom / order changes are handled inside GalleryGrid.)
    ref.listen(photosQueryControllerProvider, (previous, next) {
      if (previous != next && _scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });

    final photos = ref.watch(photosControllerProvider);

    return photos.when(
      skipLoadingOnReload: true, // keep old photos while a new filter loads
      skipLoadingOnRefresh: false, // but show the skeleton on "Try again"
      // Shimmering tiles in the grid's shape, never a spinner. The space of
      // the toolbar ("Library · N items" + filters) stays free, so the tiles
      // do not jump when the real grid arrives.
      loading: () => Padding(
        padding: const EdgeInsets.only(top: GalleryGeometry.toolbarHeight),
        child: GalleryGridSkeleton(
          columns: ref.watch(
            photosViewSettingsControllerProvider.select((s) => s.columns),
          ),
        ),
      ),
      error: (error, stackTrace) => _ErrorView(
        message: error is Failure ? error.message : 'Something went wrong.',
        onRetry: () => ref.invalidate(photosControllerProvider),
      ),
      data: (_) => _buildGrid(),
    );
  }

  Widget _buildGrid() {
    final rows = ref.watch(galleryRowsProvider);
    final items = ref.watch(photosDisplayItemsProvider);
    final settings = ref.watch(photosViewSettingsControllerProvider);
    final immersive = ref.watch(photosImmersiveActiveProvider);
    final settingsController =
        ref.read(photosViewSettingsControllerProvider.notifier);

    if (items.isEmpty) {
      return const Column(
        children: [
          SizedBox(height: GalleryGeometry.toolbarHeight, child: GalleryToolbar()),
          Expanded(child: _EmptyView()),
        ],
      );
    }

    return GalleryGrid(
      controller: _scrollController,
      rows: rows,
      items: items,
      columns: settings.columns,
      reversed: settings.order == MediaSortOrder.oldestFirst,
      immersive: immersive,
      immersiveLabelTop: widget.appBarExtent + 4,
      thumbTopInset: immersive ? widget.appBarExtent + 8 : 8,
      toolbar: const GalleryToolbar(),
      onZoomIn: settingsController.zoomIn,
      onZoomOut: settingsController.zoomOut,
    );
  }
}

class _EmptyView extends ConsumerWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = ref.watch(photosQueryControllerProvider.select((q) => q.kind));
    final message = switch (kind) {
      MediaKind.all => 'No photos or videos yet',
      MediaKind.images => 'No photos found',
      MediaKind.videos => 'No videos found',
    };

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.images,
            size: 48,
            color: context.colors.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(message, style: context.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
