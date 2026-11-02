import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:go_router/go_router.dart';
import 'package:proalbums/app/router/app_routes.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/providers/gallery_rows_provider.dart';
import 'package:proalbums/features/gallery/presentation/viewer/providers/viewer_session_provider.dart';

/// Opens the full-screen viewer on top of EVERYTHING (also above the bottom
/// navigation bar), starting at the item with [id].
///
/// [items] is WHERE the swipe list comes from: null = the Photos tab list, an
/// album passes its own list, search its results... The viewer itself is the
/// same everywhere. (How it gets there: see [ViewerSession].)
Future<void> openMediaViewer(
  BuildContext context,
  WidgetRef ref, {
  required String id,
  ProviderListenable<List<MediaItem>>? items,
}) {
  ref
      .read(viewerSessionProvider.notifier)
      .start(items ?? photosDisplayItemsProvider);
  return context.push<void>(AppRoutes.viewer(id));
}
