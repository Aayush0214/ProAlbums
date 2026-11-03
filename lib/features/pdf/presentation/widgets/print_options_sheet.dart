import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pdf/pdf.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/pdf/domain/entities/pdf_document.dart';

/// "Print" sheet, before the phone's print screen: Merge Multiple Pages and
/// Scale To (the print screen has no such options for other apps), with a
/// small example of the first sheet of paper. [aspects] = each picture's
/// shape (width / height), so the example matches the real layout. Returns
/// the chosen layout (Next), or null (Cancel / swiped away).
Future<PrintLayout?> showPrintOptionsSheet(
  BuildContext context, {
  required List<double> aspects,
}) {
  return showModalBottomSheet<PrintLayout>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _PrintOptionsSheet(aspects: aspects),
  );
}

class _PrintOptionsSheet extends StatefulWidget {
  const _PrintOptionsSheet({required this.aspects});

  final List<double> aspects;

  @override
  State<_PrintOptionsSheet> createState() => _PrintOptionsSheetState();
}

class _PrintOptionsSheetState extends State<_PrintOptionsSheet> {
  PrintLayout _layout = const PrintLayout();

  void _scaleBy(int step) => setState(() {
    final next = (_layout.scalePercent + step).clamp(
      PrintLayout.minScale,
      PrintLayout.maxScale,
    );
    _layout = _layout.copyWith(scalePercent: next);
  });

  @override
  Widget build(BuildContext context) {
    final count = widget.aspects.length;
    final sheets = (count / _layout.perSheet).ceil();
    final secondary = context.textTheme.bodyMedium?.copyWith(
      color: context.colors.textSecondary,
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Print', style: context.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              '${count == 1 ? '1 picture' : '$count pictures'} · '
              '${sheets == 1 ? '1 sheet' : '$sheets sheets'} of paper',
              style: secondary,
            ),
            const SizedBox(height: 16),
            Center(
              child: SizedBox(
                height: 200,
                child: _SheetExample(layout: _layout, aspects: widget.aspects),
              ),
            ),
            const SizedBox(height: 4),
            Center(child: Text('Example: sheet 1', style: secondary)),
            const SizedBox(height: 20),
            Text('Merge Multiple Pages', style: context.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final perSheet in PrintLayout.perSheetChoices)
                  ChoiceChip(
                    label: Text(
                      perSheet == 1 ? "Don't merge" : '$perSheet pages',
                    ),
                    selected: _layout.perSheet == perSheet,
                    showCheckmark: false,
                    // One picture has nothing to merge with.
                    onSelected: count < 2 && perSheet > 1
                        ? null
                        : (_) => setState(
                            () =>
                                _layout = _layout.copyWith(perSheet: perSheet),
                          ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text('Scale To', style: context.textTheme.titleMedium),
                ),
                IconButton.filledTonal(
                  tooltip: 'Smaller',
                  icon: const Icon(LucideIcons.minus),
                  onPressed: _layout.scalePercent > PrintLayout.minScale
                      ? () => _scaleBy(-PrintLayout.scaleStep)
                      : null,
                ),
                SizedBox(
                  width: 72,
                  child: Text(
                    '${_layout.scalePercent}%',
                    textAlign: TextAlign.center,
                    style: context.textTheme.titleMedium,
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Bigger',
                  icon: const Icon(LucideIcons.plus),
                  onPressed: _layout.scalePercent < PrintLayout.maxScale
                      ? () => _scaleBy(PrintLayout.scaleStep)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(shape: const StadiumBorder()),
                    onPressed: () => Navigator.of(context).pop(_layout),
                    child: const Text('Next'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The first sheet of paper as a drawing: an A4 page with a box per picture
/// ("Page 1", "Page 2" ...) in the same grid, shape and size as the real
/// print (same [PrintLayout] rules), but no photos. The paper size and
/// orientation chosen later in the print screen may differ.
class _SheetExample extends StatelessWidget {
  const _SheetExample({required this.layout, required this.aspects});

  final PrintLayout layout;
  final List<double> aspects;

  @override
  Widget build(BuildContext context) {
    // Everything in PDF points, drawn at [toPx].
    const paper = PdfPageFormat.a4;
    final margin = layout.pageMargin;
    final width = paper.width - 2 * margin;
    final height = paper.height - 2 * margin;
    final sheet = aspects.take(layout.perSheet).toList();
    final (columns, rows) = layout.bestGrid(
      aspects: sheet,
      width: width,
      height: height,
    );
    final cellWidth = (width - layout.gap * (columns - 1)) / columns;
    final cellHeight = (height - layout.gap * (rows - 1)) / rows;
    final scale = layout.scalePercent / 100;

    return AspectRatio(
      aspectRatio: paper.width / paper.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final toPx = constraints.maxWidth / paper.width;
          return DecoratedBox(
            decoration: BoxDecoration(
              color: context.colors.surfaceContainerHighest,
              border: Border.all(color: context.colors.dividerSubtle),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Stack(
              children: [
                for (final (index, aspect) in sheet.indexed)
                  _box(
                    context,
                    index: index,
                    aspect: aspect,
                    left: margin + (index % columns) * (cellWidth + layout.gap),
                    top:
                        margin + (index ~/ columns) * (cellHeight + layout.gap),
                    cellWidth: cellWidth,
                    cellHeight: cellHeight,
                    scale: scale,
                    toPx: toPx,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// One picture's box: as big as fits its cell with its own shape, times
  /// [scale], centred in the cell.
  Widget _box(
    BuildContext context, {
    required int index,
    required double aspect,
    required double left,
    required double top,
    required double cellWidth,
    required double cellHeight,
    required double scale,
    required double toPx,
  }) {
    final a = aspect > 0 ? aspect : 1.0;
    final fitWidth = cellWidth < cellHeight * a ? cellWidth : cellHeight * a;
    final boxWidth = fitWidth * scale;
    final boxHeight = fitWidth / a * scale;
    return Positioned(
      left: (left + (cellWidth - boxWidth) / 2) * toPx,
      top: (top + (cellHeight - boxHeight) / 2) * toPx,
      width: boxWidth * toPx,
      height: boxHeight * toPx,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.colorScheme.primaryContainer,
          border: Border.all(color: context.colorScheme.primary, width: 0.8),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Text(
                'Page ${index + 1}',
                style: context.textTheme.labelSmall?.copyWith(
                  color: context.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
