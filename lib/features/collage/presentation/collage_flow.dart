import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:proalbums/app/router/app_routes.dart';
import 'package:proalbums/features/collage/domain/collage_rules.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/providers/gallery_rows_provider.dart';
import 'package:proalbums/features/gallery/presentation/viewer/open_media_viewer.dart';
import 'package:proalbums/shared/widgets/app_snack_bar.dart';

/// Selection bar > Collage (2–9 pictures; the bar greys it out for videos and
/// a single picture). After a save the new collage opens in the viewer, like
/// the system gallery. true = saved (the selection ends).
Future<bool> makeCollage(
  BuildContext context,
  WidgetRef ref,
  List<MediaItem> items,
) async {
  final toast = AppToast.of(context);
  final pictures = [
    for (final item in items)
      if (!item.isVideo) item,
  ];
  if (pictures.length < CollageRules.minPictures) return false;
  if (pictures.length > CollageRules.maxPictures) {
    toast.show('Select up to ${CollageRules.maxPictures} pictures');
    return false;
  }
  final id = await context.push<String>(AppRoutes.collage, extra: pictures);
  if (id == null || !context.mounted) return false;

  // The library notices the new file a moment later; then show it.
  for (var i = 0; i < 30; i++) {
    if (ref.read(photosDisplayItemsProvider).any((item) => item.id == id)) {
      break;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (!context.mounted) return true;
  }
  if (context.mounted) {
    await openMediaViewer(
      context,
      ref,
      id: id,
      items: photosDisplayItemsProvider,
    );
  }
  return true;
}
