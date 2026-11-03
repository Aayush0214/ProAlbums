import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/core/theme/app_typography.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/grid/thumbnail_size.dart';
import 'package:proalbums/features/gallery/presentation/images/media_thumbnail_image.dart';
import 'package:proalbums/features/gallery/presentation/providers/media_selection.dart';
import 'package:proalbums/features/gallery/presentation/widgets/media_thumbnail.dart';
import 'package:proalbums/features/gallery/presentation/widgets/selection_checkbox.dart';
import 'package:proalbums/features/pdf/presentation/pages/convert_pdf_page.dart';
import 'package:proalbums/features/pdf/presentation/providers/pdf_providers.dart';
import 'package:proalbums/features/pdf/presentation/widgets/pdf_page_actions.dart';
import 'package:proalbums/features/pdf/presentation/widgets/pdf_page_image.dart';
import 'package:proalbums/shared/widgets/app_back_button.dart';
import 'package:reorderable_grid/reorderable_grid.dart';

/// Adjust image (from Convert PDF): the same pages as a 2-column grid with
/// their number ("4/19"). Long press + drag to reorder, tap to look at a
/// page (its viewer has "Crop & rotate"), "+" to add pictures, select (top
/// right) to remove pages with
/// Delete. Every change is the PDF's own list (pdfPagesProvider), so the
/// Convert PDF page shows it at once.
class PdfAdjustImagePage extends ConsumerStatefulWidget {
  const PdfAdjustImagePage({super.key});

  @override
  ConsumerState<PdfAdjustImagePage> createState() => _PdfAdjustImagePageState();
}

class _PdfAdjustImagePageState extends ConsumerState<PdfAdjustImagePage> {
  static const int _columns = 2;
  static const double _gap = 12;

  bool _selecting = false;
  final Set<String> _selected = {};

  void _startSelecting() => setState(() => _selecting = true);

  void _stopSelecting() => setState(() {
    _selecting = false;
    _selected.clear();
  });

  void _toggle(String id) => setState(() {
    if (!_selected.remove(id)) _selected.add(id);
  });

  void _deleteSelected() {
    ref.read(pdfPagesProvider.notifier).remove({..._selected});
    _stopSelecting();
  }

  @override
  Widget build(BuildContext context) {
    final pages = ref.watch(pdfPagesProvider);
    final load = thumbnailLoader(ref);
    final width = MediaQuery.sizeOf(context).width;
    final cell = (width - _gap * (_columns + 1)) / _columns;
    final thumbnailSize = thumbnailSizeFor(
      cellSize: cell,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );

    return PopScope(
      // Back while selecting only leaves selection.
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _stopSelecting();
      },
      child: Scaffold(
        appBar: _selecting
            ? AppBar(
                leading: IconButton(
                  tooltip: 'Cancel',
                  icon: const Icon(LucideIcons.x),
                  onPressed: _stopSelecting,
                ),
                title: Text(
                  _selected.isEmpty
                      ? 'Select items'
                      : '${_selected.length} selected',
                  style: context.textTheme.titleLarge,
                ),
              )
            : AppBar(
                leading: const AppBackButton(),
                title: Text(
                  'Adjust image',
                  style: context.textTheme.titleLarge,
                ),
                actions: [
                  IconButton(
                    tooltip: 'Select',
                    icon: const Icon(LucideIcons.squareCheckBig),
                    onPressed: pages.isEmpty ? null : _startSelecting,
                  ),
                  IconButton(
                    tooltip: 'Add pictures',
                    icon: const Icon(LucideIcons.plus),
                    onPressed: () => addPdfPictures(context, ref),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
        body: pages.isEmpty
            ? const PdfNoPages()
            : ReorderableGridView.builder(
                padding: EdgeInsets.fromLTRB(
                  _gap,
                  _gap,
                  _gap,
                  _gap + MediaQuery.paddingOf(context).bottom,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _columns,
                  crossAxisSpacing: _gap,
                  mainAxisSpacing: _gap,
                ),
                itemCount: pages.length,
                // Long press drags, except while selecting.
                itemDragEnable: (_) => !_selecting,
                // [to] already counts without the moved page.
                onReorder: (from, to) =>
                    ref.read(pdfPagesProvider.notifier).move(from, to),
                itemBuilder: (context, index) {
                  final item = pages[index];
                  return _PageTile(
                    key: ValueKey(item.id),
                    item: item,
                    label: '${index + 1}/${pages.length}',
                    thumbnailSize: thumbnailSize,
                    load: load,
                    selection: !_selecting ? null : _selected.contains(item.id),
                    onTap: _selecting
                        ? () => _toggle(item.id)
                        : () => openPdfPage(context, ref, item, editable: true),
                  );
                },
              ),
        bottomNavigationBar: _selecting
            ? _DeleteBar(onDelete: _selected.isEmpty ? null : _deleteSelected)
            : null,
      ),
    );
  }
}

/// One page: the picture (square, cropped to fill), its number in a pill in
/// the middle at the bottom, and a checkbox while selecting.
class _PageTile extends StatelessWidget {
  const _PageTile({
    required this.item,
    required this.label,
    required this.thumbnailSize,
    required this.load,
    required this.selection,
    required this.onTap,
    super.key,
  });

  final MediaItem item;
  final String label;
  final int thumbnailSize;
  final ThumbnailLoader load;

  /// null = not selecting; else whether this page is selected.
  final bool? selection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = selection ?? false;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PdfPageImage(
            item: item,
            size: thumbnailSize,
            load: load,
            fit: BoxFit.cover,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.mediaBadgeFill,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  child: Text(
                    label,
                    style: AppTypography.badgeTimestamp().copyWith(
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (selected)
            ColoredBox(
              color: context.colorScheme.primary.withValues(alpha: 0.22),
            ),
          if (selection != null)
            Positioned(
              top: 8,
              right: 8,
              child: SelectionCheckbox(
                state: selected ? SelectionState.all : SelectionState.none,
                size: 22,
                onPhoto: true,
              ),
            ),
        ],
      ),
    );
  }
}

/// Selecting: only Delete (the pages leave the PDF, not the gallery).
class _DeleteBar extends StatelessWidget {
  const _DeleteBar({required this.onDelete});

  /// null = nothing selected (greyed out).
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final color = onDelete == null
        ? context.colors.textSecondary
        : context.colorScheme.onSurface;
    return ColoredBox(
      color: context.colors.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: InkWell(
            onTap: onDelete,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.trash2, size: 20, color: color),
                const SizedBox(height: 2),
                Text(
                  'Delete',
                  style: context.textTheme.labelMedium?.copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
