import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/viewer/media_viewer_page.dart';

/// Opens the full-screen viewer on top of EVERYTHING (also above the bottom
/// navigation bar), starting at the item with [id].
///
/// [items] is WHERE the swipe list comes from: the Photos tab passes its own
/// list, an album screen will pass the album's list, search its results... The
/// viewer itself is the same everywhere.
Future<void> openMediaViewer(
  BuildContext context, {
  required String id,
  required ProviderListenable<List<MediaItem>> items,
}) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) =>
          MediaViewerPage(initialId: id, items: items),
      // Grows out of the middle with a small bounce (easeOutBack goes a
      // little past 1.0 and settles). Only a scale + fade of the finished
      // page: it costs the GPU nothing extra, so opening stays as fast.
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final grow = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeIn,
        );
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.86, end: 1).animate(grow),
            child: child,
          ),
        );
      },
    ),
  );
}
