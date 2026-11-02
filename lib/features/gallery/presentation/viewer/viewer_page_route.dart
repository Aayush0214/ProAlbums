import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:proalbums/features/gallery/presentation/viewer/media_viewer_page.dart';

/// The viewer's page for the router: grows out of the middle with a small
/// bounce (easeOutBack goes a little past 1.0 and settles). Only a scale +
/// fade of the finished page: it costs the GPU nothing extra, so opening
/// stays as fast.
Page<void> viewerPage(BuildContext context, GoRouterState state) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    child: MediaViewerPage(initialId: state.pathParameters['mediaId']!),
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
  );
}
