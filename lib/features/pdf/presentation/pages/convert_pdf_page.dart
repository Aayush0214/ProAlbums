import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/app/router/app_routes.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/widgets/media_thumbnail.dart';
import 'package:proalbums/features/pdf/domain/entities/pdf_document.dart';
import 'package:proalbums/features/pdf/domain/usecases/pdf_usecases.dart';
import 'package:proalbums/features/pdf/presentation/providers/pdf_providers.dart';
import 'package:proalbums/features/pdf/presentation/widgets/pdf_dialogs.dart';
import 'package:proalbums/features/pdf/presentation/widgets/pdf_page_actions.dart';
import 'package:proalbums/features/pdf/presentation/widgets/pdf_page_card.dart';
import 'package:proalbums/shared/widgets/app_back_button.dart';
import 'package:proalbums/shared/widgets/app_snack_bar.dart';
import 'package:proalbums/shared/widgets/confirm_dialog.dart';

/// Convert PDF: the chosen pictures as the pages of an A4 PDF, in the order
/// they were selected, look only. "+" adds more (at most [PdfRules.maxPages]
/// in all); every other change (order, delete, crop, rotate) is made in
/// Adjust image.
///
/// Save asks for a name, saves into Documents/ProAlbums and offers to view
/// it (View or Cancel close this page); Share saves with the suggested name and
/// opens the share sheet; View files opens the file manager there. Leaving
/// with unsaved changes asks first.
class ConvertPdfPage extends ConsumerStatefulWidget {
  const ConvertPdfPage({required this.items, super.key});

  /// The selected pictures, in selection order.
  final List<MediaItem> items;

  @override
  ConsumerState<ConvertPdfPage> createState() => _ConvertPdfPageState();
}

class _ConvertPdfPageState extends ConsumerState<ConvertPdfPage> {
  /// Something changed since the last save (a new page is "changed" too).
  bool _unsaved = true;

  /// The last PDF made and saved (Share reuses it while nothing changed;
  /// View files falls back to opening it).
  ExportedPdf? _last;

  /// A save / share is running (buttons ignore taps meanwhile).
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ref.read(pdfPagesProvider.notifier).start(widget.items);
    ref.read(pdfPageEditsProvider.notifier).clear();
  }

  /// Makes and saves the PDF as [name], with a progress dialog. null when it
  /// failed (a toast says so).
  Future<ExportedPdf?> _export(String name) async {
    final toast = AppToast.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    final pages = ref.read(pdfPagesProvider);
    final progress = ValueNotifier<(int, int)>((0, pages.length));
    final dialog = showPdfProgressDialog(context, progress);
    final result = await ref.read(exportPdfUseCaseProvider)(
      pages: pages,
      name: name,
      editedFiles: ref.read(pdfPageEditsProvider.notifier).files,
      onProgress: (done, total) => progress.value = (done, total),
    );
    navigator.pop();
    await dialog;
    progress.dispose();
    return result.match(
      (failure) {
        toast.show(failure.message);
        return null;
      },
      (exported) {
        if (mounted) {
          setState(() {
            _unsaved = false;
            _last = exported;
          });
        }
        return exported;
      },
    );
  }

  /// Save, then "Saved successfully": View opens the PDF in the phone's
  /// viewer, and both View and Cancel close this page (the PDF is done).
  Future<void> _save() async {
    if (_busy) return;
    final name = await showSavePdfDialog(
      context,
      suggestedName: PdfRules.defaultName(DateTime.now()),
    );
    if (name == null || !mounted) return;
    _busy = true;
    final exported = await _export(name);
    _busy = false;
    if (exported == null || !mounted) return;

    final view = await showConfirmDialog(
      context,
      title: 'Saved successfully',
      message:
          '"${exported.saved.fileName}" has been saved successfully. '
          'View now?\n\nGo to File Manager > Documents > ProAlbums to view '
          'the file.',
      confirmLabel: 'View',
      destructive: false,
    );
    if (!mounted) return;
    if (view == true) {
      final toast = AppToast.of(context);
      final opened = await ref.read(openSavedPdfUseCaseProvider)(
        exported.saved,
      );
      opened.match((failure) => toast.show(failure.message), (_) {});
      // The PDF is done: coming back from the PDF viewer lands in the grid,
      // not here.
      if (mounted) context.pop();
    } else if (view == false) {
      context.pop();
    }
  }

  /// Saves first (no name asked; nothing new is saved when the last save is
  /// still current), then the share sheet.
  Future<void> _share() async {
    if (_busy) return;
    final toast = AppToast.of(context);
    _busy = true;
    final exported =
        _last ?? await _export(PdfRules.defaultName(DateTime.now()));
    if (exported != null) {
      final shared = await ref.read(sharePdfUseCaseProvider)(exported.filePath);
      shared.match((failure) => toast.show(failure.message), (_) {});
    }
    _busy = false;
  }

  Future<void> _viewFiles() async {
    final toast = AppToast.of(context);
    final opened = await ref.read(openPdfFilesUseCaseProvider)(
      lastSavedUri: _last?.saved.uri,
    );
    opened.match((failure) => toast.show(failure.message), (_) {});
  }

  Future<void> _confirmLeave() async {
    final discard = await showConfirmDialog(
      context,
      title: 'Discard current action?',
      confirmLabel: 'Discard',
    );
    if ((discard ?? false) && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    // Any change to the pages (here or in Adjust image, a crop or turn
    // too) = not saved.
    void changed(Object? previous, Object? next) => setState(() {
      _unsaved = true;
      _last = null;
    });
    ref
      ..listen(pdfPagesProvider, changed)
      ..listen(pdfPageEditsProvider, changed);
    final pages = ref.watch(pdfPagesProvider);
    final load = thumbnailLoader(ref);
    final onSurface = context.colorScheme.onSurface;

    return PopScope(
      canPop: !_unsaved,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(),
          title: Text('Convert PDF', style: context.textTheme.titleLarge),
          actions: [
            IconButton(
              tooltip: 'Share',
              color: onSurface,
              icon: const Icon(LucideIcons.squareArrowOutUpRight),
              onPressed: pages.isEmpty ? null : _share,
            ),
            IconButton(
              tooltip: 'Save',
              color: onSurface,
              icon: const Icon(LucideIcons.save),
              onPressed: pages.isEmpty ? null : _save,
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: pages.isEmpty
            ? const PdfNoPages()
            // Look only: every change (order, delete, crop...) is made in
            // Adjust image, in one place.
            : ListView.builder(
                // Room at the bottom so the "+" button never hides a page.
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                itemCount: pages.length,
                itemBuilder: (context, index) {
                  final item = pages[index];
                  return Padding(
                    key: ValueKey(item.id),
                    padding: const EdgeInsets.only(bottom: 12),
                    child: PdfPageCard(
                      item: item,
                      number: index + 1,
                      total: pages.length,
                      load: load,
                    ),
                  );
                },
              ),
        floatingActionButton: FloatingActionButton(
          tooltip: 'Add pictures',
          onPressed: () => addPdfPictures(context, ref),
          child: const Icon(LucideIcons.plus),
        ),
        bottomNavigationBar: _BottomBar(
          onViewFiles: _viewFiles,
          onAdjustImage: pages.isEmpty
              ? null
              : () => context.push<void>(AppRoutes.pdfAdjustImage),
        ),
      ),
    );
  }
}

/// Shown when every page was removed.
class PdfNoPages extends StatelessWidget {
  const PdfNoPages({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No pictures. Tap + to add some.',
        style: context.textTheme.bodyLarge?.copyWith(
          color: context.colors.textSecondary,
        ),
      ),
    );
  }
}

/// "View files" and "Adjust image": a compact bar on its own surface colour,
/// so it reads as buttons and not as part of the list.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.onViewFiles, required this.onAdjustImage});

  final VoidCallback onViewFiles;

  /// null = greyed out (no pages).
  final VoidCallback? onAdjustImage;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.colors.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              _BarButton(
                icon: LucideIcons.file,
                label: 'View files',
                onTap: onViewFiles,
              ),
              _BarButton(
                icon: LucideIcons.image,
                label: 'Adjust image',
                onTap: onAdjustImage,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = onTap == null
        ? context.colors.textSecondary
        : context.colorScheme.onSurface;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: context.textTheme.labelMedium?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
