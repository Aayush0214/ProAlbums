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

  /// Look only, no actions: the pages of a PDF being made (Convert PDF).
  preview,

  /// The private vault ("Hidden photos"): only Unhide and Delete.
  vault,
}

/// Every action a selection or the viewer can offer, in ONE list. An action
/// is built once (see runMediaAction) and then works on every screen whose
/// context offers it.
enum MediaAction {
  share('Share', icon: LucideIcons.share2),
  moveCopy('Move/Copy', icon: LucideIcons.folderInput),
  collage('Collage', icon: LucideIcons.layoutDashboard),
  delete('Delete', icon: LucideIcons.trash2),
  restore('Restore', icon: LucideIcons.rotateCcw),
  deleteForever('Delete', icon: LucideIcons.trash2, destructive: true),
  hide('Hide'),
  copyToClipboard('Copy to clipboard'),
  convertPdf('Convert PDF'),
  print('Print'),
  googleLens('Google Lens'),
  rename('Rename'),
  compressSize('Compress size'),
  slideshow('Slideshow'),
  contactPicture('Contact profile picture'),
  rotate('Rotate'),
  convertToH264('Convert to standard codec (H.264)'),
  unhide('Unhide', icon: LucideIcons.eye),

  /// Delete from the private vault (to Recently deleted, or for good).
  deleteHidden('Delete', icon: LucideIcons.trash2, destructive: true);

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
      MediaAction.collage,
      MediaAction.delete,
    ],
    more: [
      MediaAction.hide,
      MediaAction.copyToClipboard,
      MediaAction.convertPdf,
      MediaAction.print,
    ],
  ),
  MediaContext.trash => const SelectionActions(
    bar: [MediaAction.restore, MediaAction.deleteForever],
  ),
  MediaContext.preview => const SelectionActions(bar: []),
  MediaContext.vault => const SelectionActions(
    bar: [MediaAction.unhide, MediaAction.deleteHidden],
  ),
};

/// Is [action] ON for a selection with pictures and/or videos? Options that
/// do not apply are greyed out, never hidden (like the system gallery):
///  - Copy to clipboard, Convert PDF and Print: ONLY pictures (one video in the
///    selection turns them off: they cannot do anything with a video, the
///    system gallery's PDF/PPT even says "Images only"),
///  - Collage: only pictures AND at least 2 ([count]; more than 9 says so
///    when pressed),
///  - everything else (Hide...): always.
bool isActionEnabled(
  MediaAction action, {
  required bool hasImage,
  required bool hasVideo,
  int count = 1,
}) => switch (action) {
  MediaAction.copyToClipboard ||
  MediaAction.convertPdf ||
  MediaAction.print => hasImage && !hasVideo,
  MediaAction.collage => hasImage && !hasVideo && count >= 2,
  _ => true,
};

/// Bar buttons whose "on" depends on WHAT is selected (not only "anything").
bool actionDependsOnSelection(MediaAction action) =>
    action == MediaAction.collage;

/// The viewer's "More" menu: depends on the screen AND on the item (a video
/// has its own list).
List<MediaAction> viewerMoreActionsFor(MediaContext context, MediaItem item) {
  if (context == MediaContext.trash ||
      context == MediaContext.preview ||
      context == MediaContext.vault) {
    return const [];
  }
  if (item.isVideo) {
    return const [
      MediaAction.moveCopy,
      MediaAction.hide,
      MediaAction.rename,
      MediaAction.compressSize,
      MediaAction.slideshow,
      MediaAction.convertToH264,
    ];
  }
  return const [
    MediaAction.googleLens,
    MediaAction.moveCopy,
    MediaAction.hide,
    MediaAction.rename,
    MediaAction.compressSize,
    MediaAction.slideshow,
    MediaAction.contactPicture,
    MediaAction.rotate,
    MediaAction.copyToClipboard,
    MediaAction.convertPdf,
    MediaAction.print,
  ];
}

/// The viewer's own bar for a screen, or null = the normal bar (Share, Edit,
/// Delete, More). Recently deleted only restores or deletes for good; a
/// preview has no bar at all (empty list).
List<MediaAction>? viewerBarActionsFor(
  MediaContext context,
) => switch (context) {
  MediaContext.trash => const [MediaAction.restore, MediaAction.deleteForever],
  MediaContext.preview => const [],
  MediaContext.vault => const [MediaAction.unhide, MediaAction.deleteHidden],
  MediaContext.library || MediaContext.album || MediaContext.search => null,
};

/// Heart (favourite) in the viewer: not for pictures in the trash, not in a
/// preview.
bool viewerShowsFavorite(MediaContext context) =>
    context != MediaContext.trash &&
    context != MediaContext.preview &&
    context != MediaContext.vault;

/// Info button in the viewer: not in a preview (look only).
bool viewerShowsInfo(MediaContext context) => context != MediaContext.preview;
