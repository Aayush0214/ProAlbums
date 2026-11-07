import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/albums/presentation/widgets/album_selection_widgets.dart';
import 'package:proalbums/features/gallery/presentation/actions/media_actions.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_grid.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_grid_skeleton.dart';
import 'package:proalbums/features/gallery/presentation/providers/media_selection.dart';
import 'package:proalbums/features/gallery/presentation/widgets/selection_action_bar.dart';
import 'package:proalbums/features/memories/domain/memory_rules.dart';
import 'package:proalbums/features/memories/presentation/memory_export.dart';
import 'package:proalbums/features/memories/presentation/memory_flows.dart';
import 'package:proalbums/features/memories/presentation/memory_providers.dart';
import 'package:proalbums/shared/widgets/app_back_button.dart';
import 'package:proalbums/shared/widgets/collapsing_sliver_app_bar.dart';

/// ⋮ > View Gallery: a memory's shown pictures on the SHARED grid (2
/// columns, no date headers). App bar: the title, the dates under it,
/// select, ⋮ (Gallery management / Share memories / Delete memories).
/// Selecting: Share / Set as cover / Remove / Delete, More = Copy to
/// clipboard.
class MemoryGalleryPage extends ConsumerStatefulWidget {
  const MemoryGalleryPage({required this.memoryId, super.key});

  final int memoryId;

  @override
  ConsumerState<MemoryGalleryPage> createState() => _MemoryGalleryPageState();
}

class _MemoryGalleryPageState extends ConsumerState<MemoryGalleryPage> {
  final ScrollController _scroll = ScrollController();

  String get _scopeId => memoryAlbumId(widget.memoryId);

  MediaSelectionControllerProvider get _selectionProvider =>
      mediaSelectionControllerProvider(_scopeId);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Share memories = the memory as a video (made first, then the share
  /// sheet), like the player's Share.
  Future<void> _share() async {
    final memory = ref.read(storedMemoryProvider(widget.memoryId));
    if (memory == null) return;
    await shareMemoryVideo(context, ref, memory);
  }

  Future<void> _delete() async {
    if (await deleteMemories(context, ref, [widget.memoryId]) && mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final memory = ref.watch(storedMemoryProvider(widget.memoryId));
    final itemsProvider = memoryShownItemsProvider(widget.memoryId);
    final items = ref.watch(itemsProvider);
    final loading = ref
        .watch(memoryPicturesProvider(widget.memoryId))
        .isLoading;
    final selecting = ref.watch(_selectionProvider.select((s) => s.active));
    final selection = ref.read(_selectionProvider.notifier);

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
                    ? selection.clearSelection()
                    : selection.selectAll([for (final i in items) i.id]),
                onClose: selection.exit,
              );
            },
          )
        : CollapsingSliverAppBar(
            title: memory?.title ?? '',
            leading: const AppBackButton(),
            actions: [
              if (items.isNotEmpty)
                IconButton(
                  tooltip: 'Select',
                  icon: const Icon(LucideIcons.squareCheck),
                  onPressed: selection.start,
                ),
              PopupMenuButton<void>(
                tooltip: 'More',
                icon: const Icon(LucideIcons.ellipsisVertical),
                // The page context (not the menu's): the flows outlive it.
                itemBuilder: (_) => [
                  PopupMenuItem<void>(
                    onTap: () => manageMemory(context, widget.memoryId),
                    child: const Text('Gallery management'),
                  ),
                  PopupMenuItem<void>(
                    onTap: () => unawaited(_share()),
                    child: const Text('Share memories'),
                  ),
                  PopupMenuItem<void>(
                    onTap: () => unawaited(_delete()),
                    child: const Text('Delete memories'),
                  ),
                ],
              ),
            ],
          );

    final leading = <Widget>[
      header,
      if (memory != null && !selecting)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              memoryDateText(memory.kind, memory.startMs, memory.endMs),
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ),
        ),
    ];

    return MediaScope(
      id: _scopeId,
      mediaContext: MediaContext.memory,
      items: itemsProvider,
      albumId: _scopeId,
      child: PopScope(
        canPop: !selecting,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) selection.exit();
        },
        child: Scaffold(
          bottomNavigationBar: selecting ? const SelectionActionBar() : null,
          body: items.isEmpty
              ? CustomScrollView(
                  slivers: [
                    ...leading,
                    if (loading)
                      const SliverGalleryGridSkeleton(
                        columns: memoryGalleryColumns,
                      )
                    else
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text(
                            'No images',
                            style: context.textTheme.bodyLarge?.copyWith(
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                  ],
                )
              : GalleryGrid(
                  controller: _scroll,
                  rows: ref.watch(memoryShownRowsProvider(widget.memoryId)),
                  items: items,
                  columns: memoryGalleryColumns,
                  reversed: false,
                  viewerItems: itemsProvider,
                  thumbTopInset:
                      MediaQuery.paddingOf(context).top + kToolbarHeight + 8,
                  leadingSlivers: leading,
                  // Fixed columns (like the system gallery).
                  onZoomIn: () {},
                  onZoomOut: () {},
                ),
        ),
      ),
    );
  }
}
