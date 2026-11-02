import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/favorites/presentation/providers/favorites_providers.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/viewer/widgets/viewer_actions.dart';

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
    super.key,
  });

  final MediaItem item;
  final bool showActions;

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
      favoriteIdsProvider.select((ids) => ids.value?.contains(item.id) ?? false),
    );

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
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      date,
                      style: text.titleMedium,
                    ),
                    Text(
                      time,
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
                color: isFavorite ? AppColors.favoriteHeartRed : onSurface,
                icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
                onPressed: () => toggleFavorite(ref, item),
              ),
              IconButton(
                tooltip: 'Info',
                color: infoActive ? context.colors.activeAccent : onSurface,
                icon: const Icon(Icons.info_outline),
                onPressed: onInfo,
              ),
              if (showActions) ...[
                IconButton(
                  tooltip: 'Share',
                  color: onSurface,
                  icon: const Icon(LucideIcons.share2),
                  onPressed: () => shareViewerItem(context, ref, item),
                ),
                IconButton(
                  tooltip: 'Edit',
                  color: onSurface,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => showComingSoon(context, 'Edit'),
                ),
                IconButton(
                  tooltip: 'Delete',
                  color: onSurface,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onDelete ?? () => showComingSoon(context, 'Delete'),
                ),
                ViewerMoreMenu(
                  item: item,
                  icon: Icon(Icons.more_vert, color: onSurface),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
