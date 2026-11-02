import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/albums/presentation/widgets/album_selection_widgets.dart';
import 'package:proalbums/features/trash/domain/entities/trashed_item.dart';
import 'package:proalbums/features/trash/domain/repositories/trash_repository.dart';
import 'package:proalbums/features/trash/domain/services/trash_days.dart';
import 'package:proalbums/features/trash/presentation/providers/trash_providers.dart';
import 'package:proalbums/features/trash/presentation/widgets/trashed_tile.dart';
import 'package:proalbums/shared/widgets/app_snack_bar.dart';
import 'package:proalbums/shared/widgets/collapsing_sliver_app_bar.dart';
import 'package:proalbums/shared/widgets/confirm_dialog.dart';

/// "Recently deleted": what Android keeps in its trash for 30 days. Select
/// items, then Restore (back in their albums) or Delete for good.
class RecentlyDeletedPage extends ConsumerStatefulWidget {
  const RecentlyDeletedPage({super.key});

  @override
  ConsumerState<RecentlyDeletedPage> createState() =>
      _RecentlyDeletedPageState();
}

class _RecentlyDeletedPageState extends ConsumerState<RecentlyDeletedPage> {
  static const double _gap = 2;
  static const int _columns = 3;

  bool _selecting = false;
  Set<String> _selected = {};

  void _start([String? id]) {
    HapticFeedback.selectionClick();
    setState(() {
      _selecting = true;
      _selected = {?id};
    });
  }

  void _exit() => setState(() {
        _selecting = false;
        _selected = {};
      });

  void _toggle(String id) => setState(() {
        _selected = _selected.contains(id)
            ? ({..._selected}..remove(id))
            : {..._selected, id};
      });

  Future<void> _restore(List<TrashedItem> chosen) async {
    final messenger = ScaffoldMessenger.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final result = await ref.read(restoreFromTrashUseCaseProvider)([
      for (final t in chosen) t.item,
    ]);
    result.match(
      (failure) => showAppSnackBarOn(messenger, width, failure.message),
      (outcome) {
        if (outcome != TrashActionOutcome.done) return;
        showAppSnackBarOn(
          messenger,
          width,
          chosen.length == 1 ? 'Restored.' : '${chosen.length} items restored.',
        );
        ref.invalidate(trashedItemsProvider);
        if (mounted) _exit();
      },
    );
  }

  Future<void> _deleteForever(List<TrashedItem> chosen) async {
    final yes = await showConfirmDialog(
      context,
      title: chosen.length == 1
          ? 'Delete permanently?'
          : 'Delete ${chosen.length} items permanently?',
      message:
          'This cannot be undone. The files will be removed from your phone.',
      confirmLabel: 'Delete',
    );
    if (yes != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final result = await ref.read(deleteForeverUseCaseProvider)([
      for (final t in chosen) t.item,
    ]);
    result.match(
      (failure) => showAppSnackBarOn(messenger, width, failure.message),
      (outcome) {
        if (outcome != TrashActionOutcome.done) return;
        showAppSnackBarOn(
          messenger,
          width,
          chosen.length == 1
              ? 'Deleted permanently.'
              : '${chosen.length} items deleted permanently.',
        );
        ref.invalidate(trashedItemsProvider);
        if (mounted) _exit();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final trash = ref.watch(trashedItemsProvider);
    final items = trash.value ?? const <TrashedItem>[];
    final chosen = [
      for (final t in items)
        if (_selected.contains(t.id)) t,
    ];
    final now = DateTime.now();

    final width = MediaQuery.sizeOf(context).width;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cell = (width - _gap * (_columns - 1)) / _columns;
    final thumb = ((cell * dpr) / 64).ceil() * 64;

    final Widget header = _selecting
        ? AlbumSelectionHeader(
            selectedCount: chosen.length,
            itemCount: items.length,
            onSelectAllToggle: () => setState(() {
              _selected = chosen.length == items.length
                  ? {}
                  : {for (final t in items) t.id};
            }),
            onClose: _exit,
          )
        : CollapsingSliverAppBar(
            title: 'Recently deleted',
            leading: const BackButton(),
            actions: [
              if (items.isNotEmpty)
                IconButton(
                  tooltip: 'Select',
                  icon: const Icon(Icons.check_box_outlined),
                  onPressed: _start,
                ),
            ],
          );

    return PopScope(
      // Back while selecting = leave select mode, not the screen.
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _exit();
      },
      child: Scaffold(
        bottomNavigationBar: _selecting
            ? _TrashBar(
                enabled: chosen.isNotEmpty,
                onRestore: () => _restore(chosen),
                onDelete: () => _deleteForever(chosen),
              )
            : null,
        body: CustomScrollView(
          slivers: [
            header,
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Text(
                  'Deleted content is kept for $kTrashDays days before '
                  'permanent deletion.',
                  style: context.textTheme.bodySmall
                      ?.copyWith(color: context.colors.textSecondary),
                ),
              ),
            ),
            if (trash.isLoading && items.isEmpty)
              const SliverToBoxAdapter(child: SizedBox.shrink())
            else if (trash.hasError && items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: TextButton(
                    onPressed: () => ref.invalidate(trashedItemsProvider),
                    child: const Text('Could not load. Try again'),
                  ),
                ),
              )
            else if (items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
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
                ),
              )
            else
              SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _columns,
                  mainAxisSpacing: _gap,
                  crossAxisSpacing: _gap,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final t = items[index];
                  return TrashedTile(
                    key: ValueKey(t.id),
                    trashed: t,
                    now: now,
                    thumbnailSize: thumb,
                    selecting: _selecting,
                    selected: _selected.contains(t.id),
                    // A tap opens select mode with this item (there is no
                    // viewer for the trash yet); in select mode it toggles.
                    onTap: () => _selecting ? _toggle(t.id) : _start(t.id),
                    onLongPress: () => _selecting ? _toggle(t.id) : _start(t.id),
                  );
                },
              ),
            SliverToBoxAdapter(
              child: SizedBox(height: MediaQuery.paddingOf(context).bottom),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom bar of the select mode: Restore and Delete.
class _TrashBar extends StatelessWidget {
  const _TrashBar({
    required this.enabled,
    required this.onRestore,
    required this.onDelete,
  });

  final bool enabled;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colorScheme.surface,
      elevation: 3,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _BarButton(
                icon: LucideIcons.rotateCcw,
                label: 'Restore',
                onPressed: enabled ? onRestore : null,
                color: enabled ? context.colorScheme.onSurface : Theme.of(context).disabledColor,
              ),
              _BarButton(
                icon: LucideIcons.trash2,
                label: 'Delete',
                color: enabled ? context.colorScheme.error : Theme.of(context).disabledColor,
                onPressed: enabled ? onDelete : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: context.textTheme.labelSmall?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
