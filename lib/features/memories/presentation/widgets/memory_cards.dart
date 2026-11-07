import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/widgets/media_thumbnail.dart';
import 'package:proalbums/features/memories/data/memory_repository.dart';
import 'package:proalbums/features/memories/domain/memory_rules.dart';

/// A picture of the library by id (memories and Featured hold pictures
/// only).
MediaItem memoryPicture(String id) => MediaItem(
  id: id,
  type: MediaType.image,
  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  width: 0,
  height: 0,
);

/// What a ⋮ menu of a memory offers.
enum MemoryMenuAction { viewGallery, rename, delete }

/// A memory as a square card: its cover, a dark fade at the bottom, the
/// title and the dates in white. [big] = the first card of For You and the
/// Memories page. [onMenu] shows ⋮ (View Gallery / Rename / Delete
/// memories); [selected] (not null = selecting) shows a check box instead.
class MemoryCard extends StatelessWidget {
  const MemoryCard({
    required this.memory,
    required this.onTap,
    this.big = false,
    this.onMenu,
    this.onLongPress,
    this.selected,
    super.key,
  });

  final StoredMemory memory;
  final VoidCallback onTap;
  final bool big;
  final ValueChanged<MemoryMenuAction>? onMenu;
  final VoidCallback? onLongPress;
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final titleStyle =
        (big ? context.textTheme.displaySmall : context.textTheme.titleMedium)
            ?.copyWith(
              color: AppColors.mediaBadgeText,
              fontWeight: FontWeight.w700,
            );
    final dateStyle =
        (big ? context.textTheme.titleMedium : context.textTheme.bodySmall)
            ?.copyWith(color: AppColors.mediaBadgeText);
    return _PictureCard(
      id: memory.coverId,
      radius: big ? 24 : 20,
      size: big ? 1024 : 512,
      onTap: onTap,
      onLongPress: onLongPress,
      selected: selected,
      menu: onMenu == null || selected != null
          ? null
          : PopupMenuButton<MemoryMenuAction>(
              tooltip: 'More',
              icon: const Icon(
                LucideIcons.ellipsisVertical,
                color: AppColors.mediaBadgeText,
              ),
              onSelected: onMenu,
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: MemoryMenuAction.viewGallery,
                  child: Text('View Gallery'),
                ),
                PopupMenuItem(
                  value: MemoryMenuAction.rename,
                  child: Text('Rename'),
                ),
                PopupMenuItem(
                  value: MemoryMenuAction.delete,
                  child: Text('Delete memories'),
                ),
              ],
            ),
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            memory.title,
            maxLines: big ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: titleStyle,
          ),
          Text(
            memoryDateText(memory.kind, memory.startMs, memory.endMs),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: dateStyle,
          ),
        ],
      ),
    );
  }
}

/// A Featured picture as a big card with its date. While selecting:
/// a check box and ⤢ (opens the viewer without changing the selection).
class FeaturedCard extends StatelessWidget {
  const FeaturedCard({
    required this.id,
    required this.takenMs,
    required this.onTap,
    this.onLongPress,
    this.selected,
    this.onExpand,
    super.key,
  });

  final String id;
  final int takenMs;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool? selected;
  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) => _PictureCard(
    id: id,
    radius: 24,
    size: 1024,
    onTap: onTap,
    onLongPress: onLongPress,
    selected: selected,
    onExpand: selected == null ? null : onExpand,
    label: Text(
      featuredDateText(takenMs),
      style: context.textTheme.titleMedium?.copyWith(
        color: AppColors.mediaBadgeText,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _PictureCard extends StatelessWidget {
  const _PictureCard({
    required this.id,
    required this.radius,
    required this.size,
    required this.onTap,
    required this.label,
    this.onLongPress,
    this.selected,
    this.menu,
    this.onExpand,
  });

  final String id;
  final double radius;
  final int size;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget label;
  final bool? selected;
  final Widget? menu;
  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onLongPress,
        child: Stack(
          fit: StackFit.expand,
          children: [
            MediaThumbnail(item: memoryPicture(id), size: size),
            // Dark fade so the white text reads on any picture.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.mediaScrimTop.withValues(alpha: 0),
                    AppColors.mediaScrimTop,
                  ],
                ),
              ),
            ),
            Positioned(left: 20, right: 20, bottom: 18, child: label),
            if (selected case final on?)
              Positioned(top: 14, right: 14, child: _Check(on: on))
            else if (menu case final menu?)
              Positioned(top: 4, right: 4, child: menu),
            if (onExpand case final expand?)
              Positioned(
                right: 10,
                bottom: 10,
                child: IconButton(
                  tooltip: 'Open',
                  onPressed: expand,
                  icon: const Icon(
                    LucideIcons.maximize2,
                    size: 18,
                    color: AppColors.mediaBadgeText,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _Check extends StatelessWidget {
  const _Check({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) => Container(
    width: 24,
    height: 24,
    decoration: BoxDecoration(
      color: on ? context.colorScheme.primary : AppColors.mediaBadgeFill,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: AppColors.mediaBadgeText, width: 1.5),
    ),
    child: on
        ? Icon(
            LucideIcons.check,
            size: 16,
            color: context.colorScheme.onPrimary,
          )
        : null,
  );
}
