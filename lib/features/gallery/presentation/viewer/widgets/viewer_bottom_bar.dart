import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/actions/media_actions.dart';
import 'package:proalbums/features/gallery/presentation/viewer/providers/viewer_session_provider.dart';
import 'package:proalbums/features/gallery/presentation/viewer/widgets/viewer_actions.dart';
import 'package:proalbums/shared/widgets/app_snack_bar.dart';

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
    // Some screens give the viewer their own bar (Recently deleted: Restore,
    // Delete); the others get the normal one.
    final session = ref.read(viewerSessionProvider);
    final own = viewerBarActionsFor(session.mediaContext);
    return ColoredBox(
      color: context.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: own != null
                ? [
                    for (final action in own)
                      _Action(
                        icon: action.icon ?? LucideIcons.circle,
                        label: action.label,
                        color: action.destructive
                            ? context.colorScheme.error
                            : null,
                        onPressed: () =>
                            runViewerAction(context, ref, action, item),
                      ),
                    // The opener's own buttons (e.g. Crop & rotate).
                    for (final extra in session.extraActions)
                      _Action(
                        icon: extra.icon,
                        label: extra.label,
                        onPressed: () => extra.onPressed(context, item),
                      ),
                  ]
                : [
                    _Action(
                      icon: LucideIcons.share2,
                      label: 'Share',
                      onPressed: () => shareViewerItem(context, ref, item),
                    ),
                    _Action(
                      icon: LucideIcons.squarePen,
                      label: 'Edit',
                      onPressed: () => showComingSoon(context, 'Edit'),
                    ),
                    if (item.isVideo && onPlayPause != null)
                      _Action(
                        icon: isPlaying ? LucideIcons.pause : LucideIcons.play,
                        label: isPlaying ? 'Pause' : 'Play',
                        onPressed: onPlayPause!,
                      ),
                    _Action(
                      icon: LucideIcons.trash2,
                      label: 'Delete',
                      onPressed:
                          onDelete ?? () => showComingSoon(context, 'Delete'),
                    ),
                    ViewerMoreMenu(
                      item: item,
                      child: const _ActionBody(
                        icon: LucideIcons.ellipsisVertical,
                        label: 'More',
                      ),
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
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  /// null = the theme's normal text colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: _ActionBody(icon: icon, label: label, color: color),
    );
  }
}

/// Icon with its name under it (also the look of the "More" button).
class _ActionBody extends StatelessWidget {
  const _ActionBody({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? context.colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
