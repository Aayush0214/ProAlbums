import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proalbums/features/favorites/presentation/providers/favorites_providers.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/actions/media_action_runner.dart';
import 'package:proalbums/features/gallery/presentation/actions/media_actions.dart';
import 'package:proalbums/features/gallery/presentation/providers/share_providers.dart';
import 'package:proalbums/features/gallery/presentation/viewer/providers/video_playback_controller.dart';
import 'package:proalbums/features/gallery/presentation/viewer/providers/viewer_session_provider.dart';
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

/// The "More" menu. [child] is the button the person presses. Its options
/// come from the screen the viewer was opened from (see ViewerSession) and
/// run through runMediaAction, like the grid's selection bar.
class ViewerMoreMenu extends ConsumerWidget {
  const ViewerMoreMenu({required this.item, this.child, this.icon, super.key})
    : assert(child != null || icon != null);

  final MediaItem item;

  /// A custom button (bottom bar), or just an [icon] (top bar).
  final Widget? child;
  final Widget? icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.read(viewerSessionProvider);
    final actions = viewerMoreActionsFor(session.mediaContext, item);
    if (actions.isEmpty) return const SizedBox.shrink();

    // A short menu that SCROLLS: the full list (13 options for a photo)
    // would cover the picture.
    final media = MediaQuery.of(context);
    final maxHeight =
        media.size.height *
        (media.orientation == Orientation.portrait ? 0.30 : 0.55);

    return PopupMenuButton<MediaAction>(
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
      onSelected: (action) => runMediaAction(context, ref, action, [
        item,
      ], albumId: session.albumId),
      itemBuilder: (context) => [
        for (final action in actions)
          PopupMenuItem<MediaAction>(value: action, child: Text(action.label)),
      ],
    );
  }
}

/// Runs one button of a screen's own viewer bar (see viewerBarActionsFor) on
/// the shown item. A playing video is paused first. When it is done
/// (restored, deleted for good) the item leaves the list and the viewer moves
/// to its neighbour by itself; it closes only when nothing is left (same as
/// Delete everywhere).
Future<void> runViewerAction(
  BuildContext context,
  WidgetRef ref,
  MediaAction action,
  MediaItem item,
) async {
  unawaited(ref.read(videoPlaybackProvider.notifier).pause());
  final session = ref.read(viewerSessionProvider);
  await runMediaAction(context, ref, action, [item], albumId: session.albumId);
}
