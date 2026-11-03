import 'package:flutter/material.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_geometry.dart';
import 'package:proalbums/shared/widgets/shimmer_skeleton.dart';

/// The grid's tiles as shimmering placeholders, shown while a grid loads its
/// pictures (never a spinner). Same gap and column count as the real grid,
/// so nothing jumps when the pictures arrive.
///
/// Every grid screen uses this (Photos, an album, the pickers, Recently
/// deleted...): fills the space it is given.
class GalleryGridSkeleton extends StatelessWidget {
  const GalleryGridSkeleton({required this.columns, super.key});

  final int columns;

  @override
  Widget build(BuildContext context) {
    return ShimmerSkeleton(layout: (size) => gridSkeletonBoxes(size, columns));
  }
}

/// Same, as a sliver: fills the rest of a scroll view (e.g. under an
/// album's app bar).
class SliverGalleryGridSkeleton extends StatelessWidget {
  const SliverGalleryGridSkeleton({required this.columns, super.key});

  final int columns;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: GalleryGridSkeleton(columns: columns),
    );
  }
}

/// The square tiles that fit [size], [columns] per row, with the grid's gap.
List<RRect> gridSkeletonBoxes(Size size, int columns) {
  const gap = GalleryGeometry.gap;
  final cell = (size.width - gap * (columns - 1)) / columns;
  if (cell <= 0) return const [];
  final rows = (size.height / (cell + gap)).ceil();
  return [
    for (var row = 0; row < rows; row++)
      for (var column = 0; column < columns; column++)
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            column * (cell + gap),
            row * (cell + gap),
            cell,
            cell,
          ),
          Radius.zero,
        ),
  ];
}
