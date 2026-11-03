import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/albums/presentation/widgets/album_selection_widgets.dart';
import 'package:proalbums/features/gallery/presentation/actions/media_actions.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_grid.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_grid_skeleton.dart';
import 'package:proalbums/features/gallery/presentation/providers/media_selection.dart';
import 'package:proalbums/features/gallery/presentation/widgets/selection_action_bar.dart';
import 'package:proalbums/features/trash/domain/services/trash_days.dart';
import 'package:proalbums/features/trash/presentation/providers/trash_providers.dart';
import 'package:proalbums/shared/widgets/app_back_button.dart';
import 'package:proalbums/shared/widgets/collapsing_sliver_app_bar.dart';

/// "Recently deleted": what Android keeps in its trash for 30 days, on the
/// SHARED grid (drag select, zoom, fast scroll, shimmer while loading) with
/// the trash context: select, then Restore (back in their albums) or Delete
/// for good. Each tile shows the days left; a tap opens the viewer with
/// only Restore and Delete.
class RecentlyDeletedPage extends ConsumerStatefulWidget {
  const RecentlyDeletedPage({super.key});

  @override
  ConsumerState<RecentlyDeletedPage> createState() =>
      _RecentlyDeletedPageState();
}

class _RecentlyDeletedPageState extends ConsumerState<RecentlyDeletedPage> {
  final ScrollController _scroll = ScrollController();

  static final MediaSelectionControllerProvider _selectionProvider =
      mediaSelectionControllerProvider(MediaScope.trash);

  MediaSelectionController get _selection =>
      ref.read(_selectionProvider.notifier);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trash = ref.watch(trashedItemsProvider);
    final items = ref.watch(trashMediaItemsProvider);
    final expiry = ref.watch(trashExpiryByIdProvider);
    final settings = ref.watch(trashViewSettingsProvider);
    final zoom = ref.read(trashViewSettingsProvider.notifier);
    final selecting = ref.watch(_selectionProvider.select((s) => s.active));
    final now = DateTime.now();

    // Pictures in the trash cannot be read the normal way: their small
    // pictures come from the trash itself.
    final isVideo = {for (final item in items) item.id: item.isVideo};
    final repository = ref.read(trashRepositoryProvider);
    Future<Uint8List?> loadThumbnail(String id, int size) =>
        repository.thumbnail(id: id, isVideo: isVideo[id] ?? false, size: size);

    final Widget header = selecting
        ? Consumer(
            builder: (context, ref, _) {
              final count = ref.watch(
                _selectionProvider.select((s) => s.count),
              );
              return AlbumSelectionHeader(
                selectedCount: count,
                itemCount: items.length,
                onSelectAllToggle: () => count == items.length
                    ? _selection.clearSelection()
                    : _selection.selectAll([for (final i in items) i.id]),
                onClose: _selection.exit,
              );
            },
          )
        : CollapsingSliverAppBar(
            title: 'Recently deleted',
            leading: const AppBackButton(),
            actions: [
              if (items.isNotEmpty)
                IconButton(
                  tooltip: 'Select',
                  icon: const Icon(LucideIcons.squareCheck),
                  onPressed: _selection.start,
                ),
            ],
          );

    final banner = SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Text(
          'Deleted content is kept for $kTrashDays days before permanent '
          'deletion.',
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
      ),
    );

    return MediaScope(
      id: MediaScope.trash,
      mediaContext: MediaContext.trash,
      items: trashMediaItemsProvider,
      thumbnailLoader: loadThumbnail,
      tileLabel: (item) => trashDaysLabel(trashDaysLeft(expiry[item.id], now)),
      videoSource: (item) => repository.playableVideoUri(item.id),
      child: PopScope(
        // Back while selecting = leave select mode, not the screen.
        canPop: !selecting,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _selection.exit();
        },
        child: Scaffold(
          bottomNavigationBar: selecting ? const SelectionActionBar() : null,
          body: items.isEmpty
              ? CustomScrollView(
                  slivers: [
                    header,
                    banner,
                    if (trash.isLoading)
                      SliverGalleryGridSkeleton(columns: settings.columns)
                    else
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: trash.hasError
                            ? Center(
                                child: TextButton(
                                  onPressed: () =>
                                      ref.invalidate(trashedItemsProvider),
                                  child: const Text(
                                    'Could not load. Try again',
                                  ),
                                ),
                              )
                            : const _EmptyTrash(),
                      ),
                  ],
                )
              : GalleryGrid(
                  controller: _scroll,
                  rows: ref.watch(trashGalleryRowsProvider),
                  items: items,
                  columns: settings.columns,
                  reversed: false,
                  viewerItems: trashMediaItemsProvider,
                  thumbTopInset:
                      MediaQuery.paddingOf(context).top + kToolbarHeight + 8,
                  leadingSlivers: [header, banner],
                  onZoomIn: zoom.zoomIn,
                  onZoomOut: zoom.zoomOut,
                ),
        ),
      ),
    );
  }
}

class _EmptyTrash extends StatelessWidget {
  const _EmptyTrash();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.trash2,
            size: 40,
            color: context.colors.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            'No recently deleted items',
            style: context.textTheme.bodyLarge?.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
