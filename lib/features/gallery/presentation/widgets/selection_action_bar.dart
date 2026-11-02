import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/providers/gallery_rows_provider.dart';
import 'package:proalbums/features/gallery/presentation/providers/photos_selection_controller.dart';
import 'package:proalbums/features/gallery/presentation/providers/share_providers.dart';
import 'package:proalbums/features/gallery/presentation/viewer/widgets/viewer_actions.dart';
import 'package:proalbums/features/trash/presentation/widgets/delete_flow.dart';

/// What the "More" menu of the selection bar can do.
enum SelectionMoreAction {
  hide('Hide'),
  copyToClipboard('Copy to clipboard'),
  pdfPpt('PDF/PPT'),
  print('Print');

  const SelectionMoreAction(this.label);
  final String label;
}

/// Which More options are ON, like the system gallery. All four always show;
/// the ones that do not apply are greyed out, never hidden.
/// - only pictures (one or many): all four on
/// - pictures + videos: Hide and PDF/PPT on
/// - only videos (one or many): Hide only
Map<SelectionMoreAction, bool> selectionMoreStates({
  required bool hasImage,
  required bool hasVideo,
}) {
  return {
    SelectionMoreAction.hide: true,
    SelectionMoreAction.copyToClipboard: hasImage && !hasVideo,
    SelectionMoreAction.pdfPpt: hasImage,
    SelectionMoreAction.print: hasImage && !hasVideo,
  };
}

/// Bottom bar while selecting, like the system gallery: Share, Move/Copy,
/// Create, Delete, More. Only Share works now; the rest arrive with their own
/// phases (until then they say so).
class SelectionActionBar extends ConsumerWidget {
  const SelectionActionBar({this.items, super.key});

  /// Where the selected ids are looked up. null = the Photos tab list; an
  /// album passes its own list, so the SAME bar works there.
  final ProviderListenable<List<MediaItem>>? items;

  ProviderListenable<List<MediaItem>> get _items =>
      items ?? photosDisplayItemsProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(
      photosSelectionControllerProvider.select((s) => s.count),
    );
    final scheme = Theme.of(context).colorScheme;
    final none = count == 0;

    return Material(
      color: scheme.surface,
      elevation: 3,
      // Needed because this bar REPLACES the navigation bar (see PhotosPage),
      // so it must keep clear of the phone's gesture area by itself.
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _BarAction(
                icon: Icons.ios_share,
                label: 'Share',
                onPressed: none ? null : () => _share(context, ref),
              ),
              _BarAction(
                icon: Icons.library_add_outlined,
                label: 'Move/Copy',
                onPressed:
                    none ? null : () => showComingSoon(context, 'Move/Copy'),
              ),
              _BarAction(
                icon: Icons.edit_outlined,
                label: 'Create',
                onPressed:
                    none ? null : () => showComingSoon(context, 'Create'),
              ),
              _BarAction(
                icon: Icons.delete_outline,
                label: 'Delete',
                onPressed: none ? null : () => _delete(context, ref),
              ),
              _MoreAction(enabled: !none, items: _items),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ids = ref.read(photosSelectionControllerProvider).ids;
    final items = ref
        .read(_items)
        .where((item) => ids.contains(item.id))
        .toList();
    final done = await deleteMediaItems(context, ref, items);
    // Deleted: leave selection mode. Cancelled: the selection stays.
    if (done) ref.read(photosSelectionControllerProvider.notifier).exit();
  }

  Future<void> _share(BuildContext context, WidgetRef ref) async {
    final ids = ref.read(photosSelectionControllerProvider).ids.toList();
    final messenger = ScaffoldMessenger.of(context);

    final result = await ref.read(shareMediaUseCaseProvider)(ids);

    result.match(
      (failure) => messenger.showSnackBar(
        const SnackBar(content: Text('Could not share the selected items.')),
      ),
      (_) {},
    );
  }
}

/// More menu of the selection bar (see [selectionMoreStates]).
class _MoreAction extends ConsumerWidget {
  const _MoreAction({required this.enabled, required this.items});

  final bool enabled;
  final ProviderListenable<List<MediaItem>> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = enabled
        ? Theme.of(context).colorScheme.onSurface
        : Theme.of(context).disabledColor;

    return Expanded(
      child: PopupMenuButton<SelectionMoreAction>(
        enabled: enabled,
        tooltip: 'More',
        onSelected: (action) => showComingSoon(context, action.label),
        itemBuilder: (context) {
          final ids = ref.read(photosSelectionControllerProvider).ids;
          final selected = ref
              .read(items)
              .where((item) => ids.contains(item.id))
              .toList();
          final states = selectionMoreStates(
            hasImage: selected.any((item) => !item.isVideo),
            hasVideo: selected.any((item) => item.isVideo),
          );
          PopupMenuItem<SelectionMoreAction> menuItem(
            SelectionMoreAction action, {
            required bool on,
          }) =>
              PopupMenuItem<SelectionMoreAction>(
                value: action,
                enabled: on,
                child: Text(action.label),
              );

          return [
            for (final entry in states.entries)
              menuItem(entry.key, on: entry.value),
          ];
        },
        child: _BarBody(icon: Icons.more_vert, label: 'More', color: color),
      ),
    );
  }
}

class _BarAction extends StatelessWidget {
  const _BarAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final color = onPressed != null
        ? Theme.of(context).colorScheme.onSurface
        : Theme.of(context).disabledColor;

    return Expanded(
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: _BarBody(icon: icon, label: label, color: color),
      ),
    );
  }
}

class _BarBody extends StatelessWidget {
  const _BarBody({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
