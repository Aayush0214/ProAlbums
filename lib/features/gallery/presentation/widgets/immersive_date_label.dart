import 'package:flutter/material.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/core/utils/date_label.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_geometry.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_row.dart';

/// "August 28 - today": the dates of the photos on screen, floating at the top
/// of the immersive view (which has no date headers).
class ImmersiveDateLabel extends StatefulWidget {
  const ImmersiveDateLabel({
    required this.controller,
    required this.geometry,
    required this.viewportHeight,
    super.key,
  });

  final ScrollController controller;
  final GalleryGeometry geometry;
  final double viewportHeight;

  @override
  State<ImmersiveDateLabel> createState() => _ImmersiveDateLabelState();
}

class _ImmersiveDateLabelState extends State<ImmersiveDateLabel> {
  // The text only changes when the first/last visible row changes, so we
  // remember it instead of formatting dates on every scroll tick.
  int? _firstRow;
  int? _lastRow;
  String _text = '';

  @override
  void didUpdateWidget(ImmersiveDateLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.geometry, widget.geometry)) _firstRow = null;
  }

  String _textFor(({int first, int last}) range) {
    if (range.first == _firstRow && range.last == _lastRow) return _text;
    _firstRow = range.first;
    _lastRow = range.last;

    final rows = widget.geometry.rows;
    final firstRow = rows.isEmpty ? null : rows[range.first];
    final lastRow = rows.isEmpty ? null : rows[range.last];
    if (firstRow is! ItemsRow || lastRow is! ItemsRow) return _text = '';

    final a = firstRow.items.first.createdAt;
    final b = lastRow.items.last.createdAt;
    final older = a.isBefore(b) ? a : b;
    final newer = a.isBefore(b) ? b : a;
    return _text = formatDateRange(older, newer, now: DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final geometry = widget.geometry;
        final controllerOffset =
            widget.controller.hasClients ? widget.controller.offset : 0.0;
        final offset =
            geometry.displayOffsetFor(controllerOffset, widget.viewportHeight);
        final text =
            _textFor(geometry.visibleRowRange(offset, widget.viewportHeight));
        if (text.isEmpty) return const SizedBox.shrink();

        return Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.mediaBadgeFill,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text(
                  text,
                  style: context.textTheme.labelLarge?.copyWith(
                    color: AppColors.mediaBadgeText,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
