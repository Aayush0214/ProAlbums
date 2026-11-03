import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';

/// WHERE a grid / the viewer is shown. It decides which actions are offered;
/// the grid and the viewer themselves are the same everywhere.
enum MediaContext {
  /// The Photos tab (the whole library).
  library,

  /// Inside one album.
  album,

  /// Search results (and later For You / memories).
  search,

  /// Recently deleted.
  trash,
}

/// Every action a selection or the viewer can offer, in ONE list. An action
/// is built once (see runMediaAction) and then works on every screen whose
/// context offers it.
enum MediaAction {
  share('Share', icon: LucideIcons.share2),
  moveCopy('Move/Copy', icon: LucideIcons.folderInput),
  create('Create', icon: LucideIcons.squarePen),
  delete('Delete', icon: LucideIcons.trash2),
  restore('Restore', icon: LucideIcons.rotateCcw),
  deleteForever('Delete', icon: LucideIcons.trash2, destructive: true),
  hide('Hide'),
  copyToClipboard('Copy to clipboard'),
  pdfPpt('PDF/PPT'),
  print('Print'),
  setAsWallpaper('Set as wallpaper'),
  googleLens('Google Lens'),
  rename('Rename'),
  compressSize('Compress size'),
  slideshow('Slideshow'),
  contactPicture('Contact profile picture'),
  rotate('Rotate'),
  screenMirroring('Screen Mirroring'),
  convertToH264('Convert to standard codec (H.264)');

  const MediaAction(this.label, {this.icon, this.destructive = false});

  final String label;

  /// For buttons in a bar. Menu entries are text only.
  final IconData? icon;

  /// Cannot be undone (e.g. delete for good): shown in the theme's error
  /// colour while it is enabled.
  final bool destructive;
}

/// What the selection bar of a [MediaContext] shows: buttons, then a "More"
/// menu (none when [more] is empty).
final class SelectionActions {
  const SelectionActions({required this.bar, this.more = const []});

  final List<MediaAction> bar;
  final List<MediaAction> more;
}

/// The selection bar of each screen, like the system gallery.
SelectionActions selectionActionsFor(MediaContext context) => switch (context) {
  MediaContext.library ||
  MediaContext.album ||
  MediaContext.search => const SelectionActions(
    bar: [
      MediaAction.share,
      MediaAction.moveCopy,
      MediaAction.create,
      MediaAction.delete,
    ],
    more: [
      MediaAction.hide,
      MediaAction.copyToClipboard,
      MediaAction.pdfPpt,
      MediaAction.print,
    ],
  ),
  MediaContext.trash => const SelectionActions(
    bar: [MediaAction.restore, MediaAction.deleteForever],
  ),
};

/// Is [action] ON for a selection with pictures and/or videos? Options that
/// do not apply are greyed out, never hidden (like the system gallery):
///  - Copy to clipboard and Print: only pictures,
///  - PDF/PPT: needs at least one picture,
///  - everything else: always.
bool isActionEnabled(
  MediaAction action, {
  required bool hasImage,
  required bool hasVideo,
}) => switch (action) {
  MediaAction.copyToClipboard || MediaAction.print => hasImage && !hasVideo,
  MediaAction.pdfPpt => hasImage,
  _ => true,
};

/// The viewer's "More" menu: depends on the screen AND on the item (a video
/// has its own list).
List<MediaAction> viewerMoreActionsFor(MediaContext context, MediaItem item) {
  if (context == MediaContext.trash) return const [];
  if (item.isVideo) {
    return const [
      MediaAction.setAsWallpaper,
      MediaAction.moveCopy,
      MediaAction.hide,
      MediaAction.rename,
      MediaAction.compressSize,
      MediaAction.slideshow,
      MediaAction.screenMirroring,
      MediaAction.convertToH264,
    ];
  }
  return const [
    MediaAction.setAsWallpaper,
    MediaAction.googleLens,
    MediaAction.moveCopy,
    MediaAction.hide,
    MediaAction.rename,
    MediaAction.compressSize,
    MediaAction.slideshow,
    MediaAction.contactPicture,
    MediaAction.rotate,
    MediaAction.copyToClipboard,
    MediaAction.pdfPpt,
    MediaAction.screenMirroring,
    MediaAction.print,
  ];
}

/// The viewer's own bar for a screen, or null = the normal bar (Share, Edit,
/// Delete, More). Recently deleted only restores or deletes for good.
List<MediaAction>? viewerBarActionsFor(MediaContext context) =>
    switch (context) {
      MediaContext.trash => const [
        MediaAction.restore,
        MediaAction.deleteForever,
      ],
      MediaContext.library || MediaContext.album || MediaContext.search => null,
    };

/// Heart (favourite) in the viewer: not for pictures in the trash.
bool viewerShowsFavorite(MediaContext context) => context != MediaContext.trash;
