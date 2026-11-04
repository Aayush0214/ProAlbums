import 'package:flutter/widgets.dart';
import 'package:proalbums/features/gallery/domain/entities/media_details.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/actions/media_actions.dart';
import 'package:proalbums/features/gallery/presentation/images/media_thumbnail_image.dart';
import 'package:proalbums/features/gallery/presentation/providers/gallery_rows_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'viewer_session_provider.g.dart';

/// What the viewer was opened from.
@immutable
final class ViewerSessionData {
  const ViewerSessionData({
    required this.items,
    this.mediaContext = MediaContext.library,
    this.albumId,
    this.imageLoader,
    this.videoSource,
    this.detailsLoader,
    this.extraActions = const [],
  });

  /// The swipe list (the Photos tab list, an album's list, search results).
  final ProviderListenable<List<MediaItem>> items;

  /// Which actions the viewer offers (same rules as the screen's grid).
  final MediaContext mediaContext;

  /// The album it was opened in (Move/Copy does not offer it).
  final String? albumId;

  /// Where the pictures come from (thumbnail AND screen-size picture):
  /// null = the normal way. Pictures in the trash need their own.
  final ThumbnailLoader? imageLoader;

  /// Where a video is played from: null = the normal way.
  final String Function(MediaItem item)? videoSource;

  /// Where the Info card gets its details: null = MediaStore.
  final Future<MediaDetails?> Function(String id)? detailsLoader;

  /// Buttons the opener adds to the viewer's bar (a preview has no other
  /// bar), e.g. Convert PDF's "Crop & rotate". The gallery does not know
  /// what they do.
  final List<ViewerExtraAction> extraActions;
}

/// One button of [ViewerSessionData.extraActions].
@immutable
final class ViewerExtraAction {
  const ViewerExtraAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;

  /// Called with the item on screen.
  final void Function(BuildContext context, MediaItem item) onPressed;
}

/// WHERE the viewer was opened from.
///
/// A route can only carry text, so the screen that opens the viewer puts its
/// list (and context) here first and then goes to `/viewer/<id>`. This way
/// the gallery never has to know the other features (albums, search ...):
/// they plug their own list in. If nothing was set (e.g. the app was
/// restored), the Photos tab list is used.
@Riverpod(keepAlive: true)
class ViewerSession extends _$ViewerSession {
  @override
  ViewerSessionData build() =>
      ViewerSessionData(items: photosDisplayItemsProvider);

  void start(ViewerSessionData data) => state = data;
}
