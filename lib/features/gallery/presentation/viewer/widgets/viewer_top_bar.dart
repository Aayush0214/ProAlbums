import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/favorites/presentation/providers/favorites_providers.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/actions/media_actions.dart';
import 'package:proalbums/features/gallery/presentation/viewer/providers/viewer_session_provider.dart';
import 'package:proalbums/features/gallery/presentation/viewer/widgets/viewer_actions.dart';
import 'package:proalbums/shared/widgets/app_snack_bar.dart';

/// Back button + when the photo was taken, and on the right the heart and the
/// Info button, on solid black like the system gallery.
///
/// In LANDSCAPE ([showActions]) the other actions (Share, Edit, Delete, More)
/// also live here: the screen is too short for a bottom bar.
class ViewerTopBar extends ConsumerWidget {
  const ViewerTopBar({
    required this.item,
    required this.onInfo,
    this.infoActive = false,
    this.onDelete,
    this.showActions = false,
    this.onTools,
    super.key,
  });

  final MediaItem item;
  final bool showActions;

  /// A video: the "video tools" button left of the heart (opens the video
  /// player). null = none.
  final VoidCallback? onTools;

  /// Opens / closes the Info card.
  final VoidCallback onInfo;
  final bool infoActive;

  /// Landscape only (portrait has the button in the bottom bar).
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final date = DateFormat.yMMMd().format(item.createdAt);
    final time = DateFormat.jm().format(item.createdAt);
    final isFavorite = ref.watch(
      favoriteIdsProvider.select(
        (ids) => ids.value?.contains(item.id) ?? false,
      ),
    );
    // The screen the viewer was opened from decides the actions (Recently
    // deleted: no heart, only Restore / Delete).
    final mediaContext = ref.read(viewerSessionProvider).mediaContext;
    final extraActions = ref.read(viewerSessionProvider).extraActions;
    final own = viewerBarActionsFor(mediaContext);

    // A solid bar in the theme's surface colour (light or dark), like the
    // system gallery.
    final onSurface = context.colorScheme.onSurface;
    return ColoredBox(
      color: context.colorScheme.surface,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: showActions ? kToolbarHeight : kToolbarHeight + 8,
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back',
                color: onSurface,
                icon: const Icon(LucideIcons.chevronLeft),
                onPressed: () {
                  if (context.canPop()) context.pop();
                },
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(date, style: text.titleMedium),
                    Text(time, style: text.bodySmall),
                  ],
                ),
              ),
              if (item.isVideo && onTools != null)
                IconButton(
                  tooltip: 'Video tools',
                  color: onSurface,
                  icon: const Icon(LucideIcons.squarePlay),
                  onPressed: onTools,
                ),
              if (viewerShowsFavorite(mediaContext))
                IconButton(
                  tooltip: isFavorite
                      ? 'Remove from favorites'
                      : 'Add to favorites',
                  color: isFavorite ? AppColors.favoriteHeartRed : onSurface,
                  icon: Icon(
                    // Favourite: the filled heart (Lucide has no filled icons).
                    isFavorite ? Icons.favorite : LucideIcons.heart,
                  ),
                  onPressed: () => toggleFavorite(ref, item),
                ),
              if (viewerShowsInfo(mediaContext))
                IconButton(
                  tooltip: 'Info',
                  color: infoActive ? context.colors.activeAccent : onSurface,
                  icon: const Icon(LucideIcons.info),
                  onPressed: onInfo,
                ),
              // The opener's own buttons (e.g. Crop & rotate).
              if (showActions)
                for (final extra in extraActions)
                  IconButton(
                    tooltip: extra.label,
                    color: onSurface,
                    icon: Icon(extra.icon),
                    onPressed: () => extra.onPressed(context, item),
                  ),
              if (showActions && own != null)
                for (final action in own)
                  IconButton(
                    tooltip: action.label,
                    color: action.destructive
                        ? context.colorScheme.error
                        : onSurface,
                    icon: Icon(action.icon ?? LucideIcons.circle),
                    onPressed: () =>
                        runViewerAction(context, ref, action, item),
                  )
              else if (showActions) ...[
                IconButton(
                  tooltip: 'Share',
                  color: onSurface,
                  icon: const Icon(LucideIcons.share2),
                  onPressed: () => shareViewerItem(context, ref, item),
                ),
                IconButton(
                  tooltip: 'Edit',
                  color: onSurface,
                  icon: const Icon(LucideIcons.squarePen),
                  onPressed: () => showComingSoon(context, 'Edit'),
                ),
                IconButton(
                  tooltip: 'Delete',
                  color: onSurface,
                  icon: const Icon(LucideIcons.trash2),
                  onPressed:
                      onDelete ?? () => showComingSoon(context, 'Delete'),
                ),
                ViewerMoreMenu(
                  item: item,
                  icon: Icon(LucideIcons.ellipsisVertical, color: onSurface),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
