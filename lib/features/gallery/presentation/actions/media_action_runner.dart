import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:proalbums/app/router/app_routes.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/actions/media_actions.dart';
import 'package:proalbums/features/gallery/presentation/providers/share_providers.dart';
import 'package:proalbums/features/pdf/presentation/widgets/print_pictures_flow.dart';
import 'package:proalbums/features/trash/presentation/widgets/delete_flow.dart';
import 'package:proalbums/features/trash/presentation/widgets/trash_actions.dart';
import 'package:proalbums/features/vault/presentation/vault_flows.dart';
import 'package:proalbums/shared/widgets/app_snack_bar.dart';

/// Runs [action] on [items] — from the selection bar OR the viewer. This is
/// the ONE place each action is wired, so building an action here makes it
/// work on every screen that offers it.
///
/// Returns true when it was done (the selection bar then leaves selection
/// mode); false when cancelled, failed, or nothing to leave (Share).
///
/// [albumId]: the album the items are shown in (Move/Copy does not offer it).
Future<bool> runMediaAction(
  BuildContext context,
  WidgetRef ref,
  MediaAction action,
  List<MediaItem> items, {
  String? albumId,
}) async {
  if (items.isEmpty) return false;
  switch (action) {
    case MediaAction.share:
      final toast = AppToast.of(context);
      final result = await ref.read(shareMediaUseCaseProvider)([
        for (final item in items) item.id,
      ]);
      result.match(
        (failure) => toast.show('Could not share the selected items.'),
        (_) {},
      );
      // Like the system gallery: the selection stays after sharing.
      return false;

    case MediaAction.moveCopy:
      // The albums feature, reached only by its route.
      final done = await context.push<bool>(
        AppRoutes.moveCopy(fromAlbumId: albumId),
        extra: items,
      );
      return done ?? false;

    case MediaAction.delete:
      return deleteMediaItems(context, ref, items);

    case MediaAction.restore:
      return restoreMediaItems(context, ref, items);

    case MediaAction.deleteForever:
      return deleteForeverMediaItems(context, ref, items);

    case MediaAction.copyToClipboard:
      final toast = AppToast.of(context);
      final result = await ref.read(copyToClipboardUseCaseProvider)(items);
      result.match(
        (failure) => toast.show(failure.message),
        // Android 13+ shows its own "Copied"; older Android gets ours.
        (systemConfirms) {
          if (!systemConfirms) toast.show('Copied');
        },
      );
      // Like the system gallery: the selection stays after copying.
      return false;

    case MediaAction.convertPdf:
      // The pdf feature, reached only by its route. Pictures only (the menu
      // greys it out for videos).
      final pictures = [
        for (final item in items)
          if (!item.isVideo) item,
      ];
      if (pictures.isEmpty) return false;
      await context.push<void>(AppRoutes.convertPdf, extra: pictures);
      // Like the system gallery: back in the grid, the selection is over.
      return true;

    case MediaAction.print:
      // The pdf feature makes the pages; the phone's print screen does
      // the rest. Like Share, the selection stays.
      await printPictures(context, ref, items);
      return false;

    case MediaAction.hide:
      // The vault feature: check (if the password is on), encrypt, then
      // Android asks to delete the originals.
      return hideMediaItems(context, ref, items);

    case MediaAction.create ||
        MediaAction.setAsWallpaper ||
        MediaAction.googleLens ||
        MediaAction.rename ||
        MediaAction.compressSize ||
        MediaAction.slideshow ||
        MediaAction.contactPicture ||
        MediaAction.rotate ||
        MediaAction.screenMirroring ||
        MediaAction.convertToH264 ||
        MediaAction.unhide ||
        MediaAction.deleteHidden:
      // Each one is switched on by the phase that builds it.
      showComingSoon(context, action.label);
      return false;
  }
}
