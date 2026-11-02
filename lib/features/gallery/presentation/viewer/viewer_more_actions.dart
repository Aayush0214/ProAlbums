import 'package:proalbums/features/gallery/domain/entities/media_item.dart';

/// Everything the "More" menu of the viewer can offer, in the order of the
/// system gallery. Each one is switched on by the phase that builds it; until
/// then choosing it only says "coming in a later update".
enum ViewerMoreAction {
  setAsWallpaper('Set as wallpaper'),
  googleLens('Google Lens'),
  moveCopy('Move/Copy'),
  hide('Hide'),
  rename('Rename'),
  compressSize('Compress size'),
  slideshow('Slideshow'),
  contactPicture('Contact profile picture'),
  rotate('Rotate'),
  copyToClipboard('Copy to clipboard'),
  pdfPpt('PDF/PPT'),
  screenMirroring('Screen Mirroring'),
  print('Print'),
  convertToH264('Convert to standard code (H.264)');

  const ViewerMoreAction(this.label);

  final String label;
}

/// The menu for a photo is not the same as for a video.
List<ViewerMoreAction> moreActionsFor(MediaItem item) {
  if (item.isVideo) {
    return const [
      ViewerMoreAction.setAsWallpaper,
      ViewerMoreAction.moveCopy,
      ViewerMoreAction.hide,
      ViewerMoreAction.rename,
      ViewerMoreAction.compressSize,
      ViewerMoreAction.slideshow,
      ViewerMoreAction.screenMirroring,
      ViewerMoreAction.convertToH264,
    ];
  }
  return const [
    ViewerMoreAction.setAsWallpaper,
    ViewerMoreAction.googleLens,
    ViewerMoreAction.moveCopy,
    ViewerMoreAction.hide,
    ViewerMoreAction.rename,
    ViewerMoreAction.compressSize,
    ViewerMoreAction.slideshow,
    ViewerMoreAction.contactPicture,
    ViewerMoreAction.rotate,
    ViewerMoreAction.copyToClipboard,
    ViewerMoreAction.pdfPpt,
    ViewerMoreAction.screenMirroring,
    ViewerMoreAction.print,
  ];
}
