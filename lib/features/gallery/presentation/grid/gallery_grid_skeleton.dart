import 'package:flutter/material.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_geometry.dart';

/// Empty tiles in the grid's colours, shown while a grid loads its pictures,
/// so the screen is never blank. Same gap and column count as the real grid,
/// so nothing jumps when the pictures arrive. No animation on purpose: it
/// costs the GPU nothing while the phone is busy loading.
class SliverGalleryGridSkeleton extends StatelessWidget {
  const SliverGalleryGridSkeleton({
    required this.columns,
    this.rows = 8,
    super.key,
  });

  final int columns;

  /// How many rows of empty tiles to show (more than fits on screen is fine).
  final int rows;

  @override
  Widget build(BuildContext context) {
    final color = context.colors.surfaceContainerHigh;
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: GalleryGeometry.gap,
        crossAxisSpacing: GalleryGeometry.gap,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) => ColoredBox(color: color),
        childCount: columns * rows,
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: false,
      ),
    );
  }
}
