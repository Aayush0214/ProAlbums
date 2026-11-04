import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:proalbums/features/gallery/domain/entities/media_details.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/actions/media_actions.dart';
import 'package:proalbums/features/gallery/presentation/images/media_thumbnail_image.dart';

/// What the shared grid widgets of ONE screen need to know about it: which
/// selection they use, which actions are offered (the context), which list
/// the selected ids are looked up in, and the album shown (if any).
///
/// Put it around the screen's Scaffold. The widgets below (grid rows, date
/// headers, drag select, selection bar) read it, so a new tab only wraps
/// its screen in a MediaScope and gets the whole grid + bar behaviour.
class MediaScope extends InheritedWidget {
  const MediaScope({
    required this.id,
    required super.child,
    this.mediaContext = MediaContext.library,
    this.items,
    this.albumId,
    this.pickMode = PickMode.none,
    this.onPick,
    this.onOpen,
    this.thumbnailLoader,
    this.tileLabel,
    this.videoSource,
    this.detailsLoader,
    super.key,
  }) : assert(
         pickMode != PickMode.single || onPick != null,
         'A single picker needs onPick',
       );

  /// A tap on a picture (when not selecting): null = open the viewer. A
  /// screen without a viewer for its pictures does something else (e.g.
  /// Recently deleted starts selecting).
  final ValueChanged<MediaItem>? onOpen;

  /// Where the thumbnails come from: null = the normal loader. (Pictures in
  /// Android's trash need their own.)
  final ThumbnailLoader? thumbnailLoader;

  /// A small text on each tile (e.g. "29 days" in Recently deleted); null =
  /// none. Shown instead of the video badge.
  final String? Function(MediaItem item)? tileLabel;

  /// Where the viewer plays a video from: null = the normal address. (Videos
  /// in Android's trash need their own.)
  /// (Hidden videos get a one-time address from the vault: may be async;
  /// null = cannot be played.)
  final FutureOr<String?> Function(MediaItem item)? videoSource;

  /// Where the viewer's Info card gets its details: null = MediaStore.
  /// (Hidden items have theirs in the vault; an empty path hides the Path
  /// row.)
  final Future<MediaDetails?> Function(String id)? detailsLoader;

  /// A screen that CHOOSES pictures instead of browsing them.
  final PickMode pickMode;

  /// [PickMode.single]: called with the tapped picture.
  final ValueChanged<MediaItem>? onPick;

  /// The selection of this screen (see MediaSelectionController).
  final String id;

  /// Which actions this screen offers.
  final MediaContext mediaContext;

  /// The screen's list (selected ids are looked up in it). null = the
  /// Photos tab list.
  final ProviderListenable<List<MediaItem>>? items;

  /// The album shown on this screen (Move/Copy does not offer it).
  final String? albumId;

  /// The Photos tab.
  static const String photos = 'photos';

  /// The grid inside one album.
  static String album(String albumId) => 'album:$albumId';

  /// Recently deleted.
  static const String trash = 'trash';

  /// The private vault ("Hidden photos").
  static const String vault = 'vault';

  /// A picker screen ("Select items", "Change cover"...).
  static String picker(String name) => 'picker:$name';

  /// The scope of the screen [context] is in. No dependency is made: a
  /// screen's scope never changes, and grids ask this a lot.
  static MediaScope of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<MediaScope>();
    assert(scope != null, 'No MediaScope above this widget.');
    return scope ?? const MediaScope(id: photos, child: SizedBox.shrink());
  }

  /// Same, but null when the screen has no scope (nothing is assumed).
  static MediaScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<MediaScope>();

  @override
  bool updateShouldNotify(MediaScope oldWidget) =>
      oldWidget.id != id ||
      oldWidget.mediaContext != mediaContext ||
      oldWidget.items != items ||
      oldWidget.albumId != albumId ||
      oldWidget.pickMode != pickMode;
}

/// How the shared grid behaves on a screen.
enum PickMode {
  /// Browse: tap opens the viewer, long press starts selecting.
  none,

  /// Choose ONE picture: tap picks it at once (e.g. Change cover).
  single,

  /// Choose many: checkboxes always shown, tap selects / unselects, drag
  /// select works (e.g. "Select items").
  multi,
}
