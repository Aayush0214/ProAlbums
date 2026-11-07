import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/app/router/app_routes.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/actions/media_actions.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_grid.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_grid_skeleton.dart';
import 'package:proalbums/features/gallery/presentation/providers/media_selection.dart';
import 'package:proalbums/features/memories/data/memory_repository.dart';
import 'package:proalbums/features/memories/domain/memory_rules.dart';
import 'package:proalbums/features/memories/presentation/memory_providers.dart';
import 'package:proalbums/shared/widgets/app_back_button.dart';
import 'package:proalbums/shared/widgets/app_snack_bar.dart';

/// Gallery management (like the system gallery): every picture of a
/// memory on the SHARED grid in picker mode (check boxes always, tap /
/// drag = tick), the ticked ones are shown in the memory (at most
/// [MemoryRules.maxShown]; "Shown (N/50)"). "+" adds pictures from the
/// library. Every change is saved at once.
class MemoryManagePage extends ConsumerStatefulWidget {
  const MemoryManagePage({required this.memoryId, super.key});

  final int memoryId;

  @override
  ConsumerState<MemoryManagePage> createState() => _MemoryManagePageState();
}

class _MemoryManagePageState extends ConsumerState<MemoryManagePage> {
  final ScrollController _scroll = ScrollController();

  /// The ticks start as the memory's shown pictures (once).
  bool _started = false;
  Timer? _save;

  /// Ticks not saved yet (saved a moment after the last change, or when
  /// the page closes).
  Set<String>? _pending;

  // Kept from the start: `ref` cannot be used once the page is closing.
  late final MemoryStore _memories = ref.read(memoryStoreProvider);
  late final MemoryScan _scan = ref.read(memoryScanProvider.notifier);

  String get _scopeId => 'memory-manage:${widget.memoryId}';

  MediaSelectionControllerProvider get _selectionProvider =>
      mediaSelectionControllerProvider(_scopeId);

  @override
  void initState() {
    super.initState();
    // Read now (see above).
    _memories;
    _scan;
  }

  @override
  void dispose() {
    _save?.cancel();
    // Leaving: save what is ticked right now.
    if (_pending case final ids?) unawaited(_store(ids));
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _store(Set<String> ids) async {
    _pending = null;
    await _memories.setShown(widget.memoryId, ids);
    _scan.changed();
  }

  /// "+": pictures from the library, added and shown (room permitting).
  Future<void> _add() async {
    final toast = AppToast.of(context);
    final shown = ref.read(_selectionProvider).count;
    final room = MemoryRules.maxShown - shown;
    if (room <= 0) {
      toast.show('Up to ${MemoryRules.maxShown} items can be shown');
      return;
    }
    final picked = await context.push<List<MediaItem>>(
      AppRoutes.pickItemsWith(max: room, imagesOnly: true),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    _save?.cancel();
    _pending = null;
    final ids = {...ref.read(_selectionProvider).ids};
    await ref.read(memoryStoreProvider).setShown(widget.memoryId, ids);
    await ref.read(memoryStoreProvider).add(widget.memoryId, [
      for (final item in picked)
        (id: item.id, takenMs: item.createdAt.millisecondsSinceEpoch),
    ]);
    ref.read(memoryScanProvider.notifier).changed();
    ref.read(_selectionProvider.notifier).selectAll({
      ...ids,
      for (final item in picked) item.id,
    });
  }

  @override
  Widget build(BuildContext context) {
    final pictures = ref.watch(memoryPicturesProvider(widget.memoryId));
    final itemsProvider = memoryAllItemsProvider(widget.memoryId);
    final items = ref.watch(itemsProvider);
    final count = ref.watch(_selectionProvider.select((s) => s.count));

    // Start with the shown pictures ticked (once the list is read).
    if (!_started && pictures.hasValue) {
      _started = true;
      final shown = {
        for (final p in pictures.value!)
          if (p.shown) p.id,
      };
      Future.microtask(
        () => ref.read(_selectionProvider.notifier).selectAll(shown),
      );
    }

    // At most 50 ticked (a drag past it is taken back); every change is
    // saved a moment later.
    ref.listen(_selectionProvider, (previous, next) {
      if (!_started || previous == null || !previous.active) return;
      if (next.count > MemoryRules.maxShown) {
        ref
            .read(_selectionProvider.notifier)
            .setIds(next.ids.take(MemoryRules.maxShown).toSet());
        AppToast.of(context)
            .show('Up to ${MemoryRules.maxShown} items can be shown');
        return;
      }
      if (previous.ids.length == next.ids.length &&
          previous.ids.containsAll(next.ids)) {
        return;
      }
      _save?.cancel();
      _pending = next.ids;
      _save = Timer(
        const Duration(milliseconds: 400),
        () => unawaited(_store(next.ids)),
      );
    });

    final caption = SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Text(
          'The selected items will be shown in "Memories".',
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
      ),
    );

    return MediaScope(
      id: _scopeId,
      mediaContext: MediaContext.memory,
      items: itemsProvider,
      albumId: memoryAlbumId(widget.memoryId),
      pickMode: PickMode.multi,
      child: Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(),
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Gallery management', style: context.textTheme.titleLarge),
              Text(
                'Shown ($count/${MemoryRules.maxShown})',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Add',
              icon: const Icon(LucideIcons.plus),
              onPressed: () => unawaited(_add()),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: items.isEmpty
            ? CustomScrollView(
                slivers: [
                  caption,
                  if (pictures.isLoading)
                    const SliverGalleryGridSkeleton(
                      columns: memoryManageColumns,
                    ),
                ],
              )
            : GalleryGrid(
                controller: _scroll,
                rows: ref.watch(memoryAllRowsProvider(widget.memoryId)),
                items: items,
                columns: memoryManageColumns,
                reversed: false,
                viewerItems: itemsProvider,
                thumbTopInset: 8,
                leadingSlivers: [caption],
                onZoomIn: () {},
                onZoomOut: () {},
              ),
      ),
    );
  }
}
