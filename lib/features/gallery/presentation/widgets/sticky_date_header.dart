import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_geometry.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_row.dart';
import 'package:proalbums/features/gallery/presentation/widgets/date_header.dart';

/// The date header that stays at the top while its day is scrolling.
///
/// It listens to the scroll controller by itself, so only THIS small widget
/// rebuilds on every scroll tick, never the whole list. The header itself is
/// only rebuilt when the stuck day changes.
class StickyDateHeader extends StatefulWidget {
  const StickyDateHeader({
    required this.controller,
    required this.geometry,
    required this.viewportHeight,
    super.key,
  });

  final ScrollController controller;
  final GalleryGeometry geometry;
  final double viewportHeight;

  @override
  State<StickyDateHeader> createState() => _StickyDateHeaderState();
}

class _StickyDateHeaderState extends State<StickyDateHeader> {
  GalleryGeometry? _cachedGeometry;
  int? _cachedRow;
  Widget? _cachedHeader;

  Widget _headerFor(DateHeaderRow row, int rowIndex) {
    if (!identical(_cachedGeometry, widget.geometry) ||
        _cachedRow != rowIndex ||
        _cachedHeader == null) {
      _cachedGeometry = widget.geometry;
      _cachedRow = rowIndex;
      _cachedHeader = DateHeader(
        day: row.day,
        itemIds: row.itemIds,
        granularity: row.granularity,
      );
    }
    return _cachedHeader!;
  }

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).scaffoldBackgroundColor;

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final geometry = widget.geometry;
        final controllerOffset =
            widget.controller.hasClients ? widget.controller.offset : 0.0;
        final offset =
            geometry.displayOffsetFor(controllerOffset, widget.viewportHeight);

        final sticky = geometry.stickyHeaderAt(offset);
        if (sticky == null) return const SizedBox.shrink();

        final row = geometry.rows[sticky.rowIndex] as DateHeaderRow;

        // When the next header comes close, push this one up and out.
        var dy = 0.0;
        if (sticky.nextStart case final nextStart?) {
          dy = math.min(0, nextStart - offset - GalleryGeometry.headerHeight);
        }

        return Transform.translate(
          offset: Offset(0, dy),
          child: ColoredBox(
            color: background,
            child: SizedBox(
              height: GalleryGeometry.headerHeight,
              child: _headerFor(row, sticky.rowIndex),
            ),
          ),
        );
      },
    );
  }
}
