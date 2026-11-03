import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:go_router/go_router.dart';
import 'package:proalbums/app/router/app_routes.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/actions/media_actions.dart';
import 'package:proalbums/features/gallery/presentation/providers/gallery_rows_provider.dart';
import 'package:proalbums/features/gallery/presentation/providers/media_scope.dart';
import 'package:proalbums/features/gallery/presentation/viewer/providers/viewer_session_provider.dart';

/// Opens the full-screen viewer on top of EVERYTHING (also above the bottom
/// navigation bar), starting at the item with [id].
///
/// [items] is WHERE the swipe list comes from: null = the screen's list from
/// its [MediaScope] (or the Photos tab list). The viewer itself is the same
/// everywhere; the screen's context decides its actions. (How it gets there:
/// see [ViewerSession].)
Future<void> openMediaViewer(
  BuildContext context,
  WidgetRef ref, {
  required String id,
  ProviderListenable<List<MediaItem>>? items,
}) {
  final scope = MediaScope.maybeOf(context);
  ref.read(viewerSessionProvider.notifier).start(
        ViewerSessionData(
          items: items ?? scope?.items ?? photosDisplayItemsProvider,
          mediaContext: scope?.mediaContext ?? MediaContext.library,
          albumId: scope?.albumId,
          imageLoader: scope?.thumbnailLoader,
          videoSource: scope?.videoSource,
        ),
      );
  return context.push<void>(AppRoutes.viewer(id));
}
