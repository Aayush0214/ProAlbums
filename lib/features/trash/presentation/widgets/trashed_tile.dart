import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/gallery/presentation/providers/photos_selection_controller.dart';
import 'package:proalbums/features/gallery/presentation/widgets/selection_checkbox.dart';
import 'package:proalbums/features/trash/domain/entities/trashed_item.dart';
import 'package:proalbums/features/trash/domain/services/trash_days.dart';
import 'package:proalbums/features/trash/presentation/providers/trash_providers.dart';

/// One picture of "Recently deleted": the small picture, the days left, and
/// (in select mode) a checkbox.
class TrashedTile extends ConsumerWidget {
  const TrashedTile({
    required this.trashed,
    required this.now,
    required this.selecting,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    this.thumbnailSize = 256,
    super.key,
  });

  final TrashedItem trashed;
  final DateTime now;
  final bool selecting;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final int thumbnailSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(
      trashThumbnailProvider(trashed.id, trashed.item.isVideo, thumbnailSize),
    );
    final days = trashDaysLeft(trashed.expiresAt, now);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: context.colorScheme.surfaceContainerHigh,
            child: switch (bytes) {
              AsyncData(:final value) when value != null => Image.memory(
                  value,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.low,
                ),
              AsyncData() || AsyncError() => Icon(
                  trashed.item.isVideo ? LucideIcons.video : LucideIcons.image,
                  color: context.colors.textSecondary,
                ),
              _ => const SizedBox.shrink(),
            },
          ),
          Positioned(
            left: 6,
            bottom: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.mediaBadgeFill,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  trashDaysLabel(days),
                  style: context.textTheme.labelSmall
                      ?.copyWith(color: AppColors.mediaBadgeText),
                ),
              ),
            ),
          ),
          if (selecting)
            Positioned(
              top: 6,
              right: 6,
              child: IgnorePointer(
                child: SelectionCheckbox(
                  state: selected ? SelectionState.all : SelectionState.none,
                  size: 20,
                  onPhoto: true,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
