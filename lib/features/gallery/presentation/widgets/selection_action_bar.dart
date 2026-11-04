import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/actions/media_action_runner.dart';
import 'package:proalbums/features/gallery/presentation/actions/media_actions.dart';
import 'package:proalbums/features/gallery/presentation/providers/gallery_rows_provider.dart';
import 'package:proalbums/features/gallery/presentation/providers/media_selection.dart';

/// Bottom bar while selecting, like the system gallery. WHAT it offers comes
/// from the screen's [MediaScope] context (e.g. Share, Move/Copy, Create,
/// Delete, More on the Photos tab; Restore, Delete in Recently deleted), and
/// every action runs through [runMediaAction], so the bar is the same widget
/// on every screen.
class SelectionActionBar extends StatelessWidget {
  const SelectionActionBar({this.backgroundColor, super.key});

  /// null = the theme's surface (most screens); a screen can set its own so
  /// the bar stands out (the private vault).
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final scope = MediaScope.of(context);
    final actions = selectionActionsFor(scope.mediaContext);
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: backgroundColor ?? scheme.surface,
      elevation: 3,
      // Needed because this bar REPLACES the navigation bar (see PhotosPage),
      // so it must keep clear of the phone's gesture area by itself.
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (final action in actions.bar) _BarAction(action: action),
              if (actions.more.isNotEmpty) _MoreAction(actions: actions.more),
            ],
          ),
        ),
      ),
    );
  }
}

/// The selected items of this screen, in the screen's order.
List<MediaItem> _selectedItems(BuildContext context, WidgetRef ref) {
  final scope = MediaScope.of(context);
  final ids = ref.read(mediaSelectionOf(context)).ids;
  return ref
      .read(scope.items ?? photosDisplayItemsProvider)
      .where((item) => ids.contains(item.id))
      .toList();
}

Future<void> _run(
  BuildContext context,
  WidgetRef ref,
  MediaAction action,
) async {
  // Taken before the await: the screen (and this bar) may be gone when the
  // action finishes (e.g. every picture moved out of an album).
  final selection = ref.read(mediaSelectionOf(context).notifier);
  final done = await runMediaAction(
    context,
    ref,
    action,
    _selectedItems(context, ref),
    albumId: MediaScope.of(context).albumId,
  );
  // Done: leave selection mode. Cancelled: the selection stays.
  if (done) selection.exitIfOpen();
}

class _BarAction extends ConsumerWidget {
  const _BarAction({required this.action});

  final MediaAction action;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only "anything selected?" rebuilds the button.
    final enabled = ref.watch(
      mediaSelectionOf(context).select((s) => s.count > 0),
    );
    // Disabled: every button the same grey. Enabled: a destructive one
    // (delete for good) in the theme's error colour.
    final scheme = Theme.of(context).colorScheme;
    final color = !enabled
        ? Theme.of(context).disabledColor
        : action.destructive
        ? scheme.error
        : scheme.onSurface;

    return Expanded(
      child: InkWell(
        onTap: enabled ? () => _run(context, ref, action) : null,
        borderRadius: BorderRadius.circular(12),
        child: _BarBody(
          icon: action.icon ?? LucideIcons.circle,
          label: action.label,
          color: color,
        ),
      ),
    );
  }
}

/// More menu of the selection bar. Options that do not apply to the
/// selection are greyed out (see [isActionEnabled]).
class _MoreAction extends ConsumerWidget {
  const _MoreAction({required this.actions});

  final List<MediaAction> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(
      mediaSelectionOf(context).select((s) => s.count > 0),
    );
    final color = enabled
        ? Theme.of(context).colorScheme.onSurface
        : Theme.of(context).disabledColor;

    return Expanded(
      child: PopupMenuButton<MediaAction>(
        enabled: enabled,
        tooltip: 'More',
        onSelected: (action) => _run(context, ref, action),
        itemBuilder: (menuContext) {
          final selected = _selectedItems(context, ref);
          final hasImage = selected.any((item) => !item.isVideo);
          final hasVideo = selected.any((item) => item.isVideo);
          return [
            for (final action in actions)
              PopupMenuItem<MediaAction>(
                value: action,
                enabled: isActionEnabled(
                  action,
                  hasImage: hasImage,
                  hasVideo: hasVideo,
                ),
                child: Text(action.label),
              ),
          ];
        },
        child: _BarBody(
          icon: LucideIcons.ellipsisVertical,
          label: 'More',
          color: color,
        ),
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
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
