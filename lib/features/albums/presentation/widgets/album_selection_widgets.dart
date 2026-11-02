import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/albums/domain/entities/album.dart';
import 'package:proalbums/features/albums/presentation/widgets/album_tile.dart';
import 'package:proalbums/features/gallery/presentation/providers/photos_selection_controller.dart';
import 'package:proalbums/features/gallery/presentation/widgets/selection_checkbox.dart';

/// An album tile in select mode: a checkbox in the corner, a tap selects.
class SelectableAlbumTile extends StatelessWidget {
  const SelectableAlbumTile({
    required this.album,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final Album album;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AlbumTile(album: album, onTap: onTap),
        Positioned(
          top: 8,
          right: 8,
          child: IgnorePointer(
            child: SelectionCheckbox(
              state: selected ? SelectionState.all : SelectionState.none,
              size: 20,
              onPhoto: true,
            ),
          ),
        ),
      ],
    );
  }
}

/// "N selected" + "X images or videos in total", select-all on the left,
/// close on the right. Pinned, like the normal app bar it replaces.
class AlbumSelectionHeader extends StatelessWidget {
  const AlbumSelectionHeader({
    required this.selectedCount,
    required this.itemCount,
    required this.onSelectAllToggle,
    required this.onClose,
    this.subtitle,
    super.key,
  });

  final int selectedCount;

  /// Under "N selected" (null = nothing there).
  final String? subtitle;
  final int itemCount;
  final VoidCallback onSelectAllToggle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _HeaderDelegate(
        topPadding: MediaQuery.paddingOf(context).top,
        selectedCount: selectedCount,
        subtitle: subtitle,
        itemCount: itemCount,
        onSelectAllToggle: onSelectAllToggle,
        onClose: onClose,
      ),
    );
  }
}

class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  _HeaderDelegate({
    required this.topPadding,
    required this.selectedCount,
    required this.subtitle,
    required this.itemCount,
    required this.onSelectAllToggle,
    required this.onClose,
  });

  final double topPadding;
  final int selectedCount;
  final String? subtitle;
  final int itemCount;
  final VoidCallback onSelectAllToggle;
  final VoidCallback onClose;

  static const double _height = kToolbarHeight + 8;

  @override
  double get minExtent => topPadding + _height;

  @override
  double get maxExtent => topPadding + _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final all = selectedCount > 0 && selectedCount == itemCount;
    final state = selectedCount == 0
        ? SelectionState.none
        : (all ? SelectionState.all : SelectionState.partial);
    final title = selectedCount == 0 ? 'Select items' : '$selectedCount selected';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: Theme.of(context).brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Padding(
          padding: EdgeInsets.only(top: topPadding),
          child: Row(
            children: [
              IconButton(
                tooltip: all ? 'Deselect all' : 'Select all',
                icon: SelectionCheckbox(state: state),
                onPressed: onSelectAllToggle,
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title, style: context.textTheme.titleLarge),
                    if (selectedCount > 0 && subtitle != null)
                      Text(
                        subtitle!,
                        style: context.textTheme.bodySmall
                            ?.copyWith(color: context.colors.textSecondary),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Cancel',
                icon: const Icon(LucideIcons.x),
                onPressed: onClose,
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_HeaderDelegate old) =>
      old.topPadding != topPadding ||
      old.selectedCount != selectedCount ||
      old.subtitle != subtitle ||
      old.itemCount != itemCount;
}

/// One button of [AlbumActionBar]. A null [onPressed] = disabled (greyed).
class AlbumBarAction {
  const AlbumBarAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
}

/// Bottom bar of the select mode. It takes the place of the navigation bar.
/// [moreItems] fills the "More" menu; it is greyed when null.
class AlbumActionBar extends StatelessWidget {
  const AlbumActionBar({
    required this.actions,
    required this.moreLabel,
    required this.onMore,
    super.key,
  });

  final List<AlbumBarAction> actions;

  /// The one entry of the "More" menu (for example "Change cover").
  final String moreLabel;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 3,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final action in actions)
                _Button(
                  icon: action.icon,
                  label: action.label,
                  onPressed: action.onPressed,
                ),
              _MoreButton(label: moreLabel, onSelected: onMore),
            ],
          ),
        ),
      ),
    );
  }
}

class _Button extends StatelessWidget {
  const _Button({
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
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: color, height: 1.15),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.label, required this.onSelected});

  final String label;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final enabled = onSelected != null;
    final color = enabled
        ? Theme.of(context).colorScheme.onSurface
        : Theme.of(context).disabledColor;
    return PopupMenuButton<int>(
      enabled: enabled,
      tooltip: 'More',
      // The menu opens ABOVE the bar, not over it.
      offset: const Offset(0, -64),
      onSelected: (_) => onSelected?.call(),
      itemBuilder: (context) => [PopupMenuItem(value: 0, child: Text(label))],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.more_vert, size: 22, color: color),
            const SizedBox(height: 4),
            Text(
              'More',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
