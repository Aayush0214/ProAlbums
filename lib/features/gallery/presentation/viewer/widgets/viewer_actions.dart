import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proalbums/features/favorites/presentation/providers/favorites_providers.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/providers/share_providers.dart';
import 'package:proalbums/features/gallery/presentation/viewer/viewer_more_actions.dart';
import 'package:proalbums/shared/widgets/app_snack_bar.dart';

/// The viewer's actions live here ONCE, so the bottom bar (portrait) and the
/// top bar (landscape) both call the same code.
Future<void> shareViewerItem(
  BuildContext context,
  WidgetRef ref,
  MediaItem item,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final width = MediaQuery.sizeOf(context).width;
  final result = await ref.read(shareMediaUseCaseProvider)([item.id]);
  result.match(
    (failure) =>
        showAppSnackBarOn(messenger, width, 'Could not share this item.'),
    (_) {},
  );
}

/// Heart on / off. Reads the current state, so there is nothing to pass in.
Future<void> toggleFavorite(WidgetRef ref, MediaItem item) async {
  final isFavorite =
      ref.read(favoriteIdsProvider).value?.contains(item.id) ?? false;
  unawaited(HapticFeedback.selectionClick());
  await ref.read(setFavoriteUseCaseProvider)([item.id], value: !isFavorite);
}

/// For buttons whose phase is not built yet.
void showComingSoon(BuildContext context, String what) {
  showAppSnackBar(context, '$what is coming in a later update.');
}

/// The "More" menu. [child] is the button the person presses.
class ViewerMoreMenu extends StatelessWidget {
  const ViewerMoreMenu({required this.item, this.child, this.icon, super.key})
      : assert(child != null || icon != null);

  final MediaItem item;

  /// A custom button (bottom bar), or just an [icon] (top bar).
  final Widget? child;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    // A short menu that SCROLLS: the full list (13 options for a photo)
    // would cover the picture.
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height *
        (media.orientation == Orientation.portrait ? 0.30 : 0.55);

    return PopupMenuButton<ViewerMoreAction>(
      tooltip: 'More',
      // From the bottom bar the menu opens ABOVE the bar (like the system
      // gallery), so the bar stays visible. The list is taller than
      // maxHeight, so the menu is exactly maxHeight tall. (From the top bar,
      // in landscape, it opens where the button is, as before.)
      offset: child != null ? Offset(0, -(maxHeight + 12)) : Offset.zero,
      constraints: BoxConstraints(
        minWidth: 112,
        maxWidth: 280,
        maxHeight: maxHeight,
      ),
      icon: icon,
      child: child,
      onSelected: (action) => showComingSoon(context, action.label),
      itemBuilder: (context) => [
        for (final action in moreActionsFor(item))
          PopupMenuItem<ViewerMoreAction>(
            value: action,
            child: Text(action.label),
          ),
      ],
    );
  }
}
