import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/viewer/widgets/viewer_actions.dart';

/// The action bar under the picture: its OWN solid bar, not text floating on
/// the photo. Share, Edit, (Play / Pause for a video), Delete, More.
class ViewerBottomBar extends ConsumerWidget {
  const ViewerBottomBar({
    required this.item,
    this.isPlaying = false,
    this.onPlayPause,
    this.onDelete,
    super.key,
  });

  final MediaItem item;

  /// Videos only: the play / pause button sits in the middle of the bar, like
  /// the system gallery.
  final bool isPlaying;
  final VoidCallback? onPlayPause;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ColoredBox(
      color: context.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _Action(
                icon: LucideIcons.share2,
                label: 'Share',
                onPressed: () => shareViewerItem(context, ref, item),
              ),
              _Action(
                icon: Icons.edit_outlined,
                label: 'Edit',
                onPressed: () => showComingSoon(context, 'Edit'),
              ),
              if (item.isVideo && onPlayPause != null)
                _Action(
                  icon: isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  label: isPlaying ? 'Pause' : 'Play',
                  onPressed: onPlayPause!,
                ),
              _Action(
                icon: Icons.delete_outline,
                label: 'Delete',
                onPressed:
                    onDelete ?? () => showComingSoon(context, 'Delete'),
              ),
              ViewerMoreMenu(
                item: item,
                child: const _ActionBody(icon: Icons.more_vert, label: 'More'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: _ActionBody(icon: icon, label: label),
    );
  }
}

/// Icon with its name under it (also the look of the "More" button).
class _ActionBody extends StatelessWidget {
  const _ActionBody({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: context.colorScheme.onSurface),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: context.colorScheme.onSurface),
          ),
        ],
      ),
    );
  }
}
