import 'dart:typed_data';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/pdf/domain/entities/pdf_document.dart';
import 'package:proalbums/features/pdf/presentation/providers/pdf_providers.dart';
import 'package:proalbums/shared/widgets/app_snack_bar.dart';

/// The crop shapes offered (null = free).
const List<(String, double?)> _ratios = [
  ('Free', null),
  ('A4', 210 / 297),
  ('1:1', 1),
  ('4:3', 4 / 3),
  ('16:9', 16 / 9),
];

/// "Crop & rotate" for ONE page of the PDF being made (from the viewer of
/// Adjust image). Drag the frame's corners / edges to crop, pinch / drag
/// the picture, choose a crop shape, turn by 90°, mirror, or start over.
/// Done keeps the result for the PDF only; the gallery picture never
/// changes. Edits add up: editing again starts from the last result.
class PdfPageEditorPage extends ConsumerStatefulWidget {
  const PdfPageEditorPage({required this.pageId, super.key});

  /// The page's id (the gallery picture's id).
  final String pageId;

  @override
  ConsumerState<PdfPageEditorPage> createState() => _PdfPageEditorPageState();
}

class _PdfPageEditorPageState extends ConsumerState<PdfPageEditorPage> {
  final ImageEditorController _editor = ImageEditorController();
  late final Future<Uint8List?> _source = _load();
  double? _ratio;
  bool _saving = false;

  Future<Uint8List?> _load() async {
    final edit = ref.read(pdfPageEditsProvider)[widget.pageId];
    final result = await ref.read(loadPdfPageUseCaseProvider)(
      widget.pageId,
      edit: edit,
    );
    return result.fold((_) => null, (bytes) => bytes);
  }

  @override
  void dispose() {
    _editor.dispose();
    super.dispose();
  }

  void _setRatio(double? ratio) {
    setState(() => _ratio = ratio);
    _editor.updateCropAspectRatio(ratio);
  }

  void _reset() {
    _editor.reset();
    _setRatio(null);
  }

  /// What the user did, as the picture's own pixels.
  PdfPageEditSpec? _spec() {
    final details = _editor.editActionDetails;
    final rect = _editor.getCropRect();
    if (details == null || rect == null) return null;
    return PdfPageEditSpec(
      rotateDegrees: details.rotateDegrees,
      flip: details.flipY,
      crop: details.needCrop
          ? (
              left: rect.left.round(),
              top: rect.top.round(),
              width: rect.width.round(),
              height: rect.height.round(),
            )
          : null,
    );
  }

  Future<void> _done(Uint8List source) async {
    if (_saving) return;
    final spec = _spec();
    if (spec == null || spec.isEmpty) {
      context.pop();
      return;
    }
    final toast = AppToast.of(context);
    setState(() => _saving = true);
    final result = await ref.read(editPdfPageUseCaseProvider)(
      id: widget.pageId,
      source: source,
      spec: spec,
    );
    if (!mounted) return;
    result.match(
      (failure) {
        setState(() => _saving = false);
        toast.show(failure.message);
      },
      (edit) {
        ref.read(pdfPageEditsProvider.notifier).set(widget.pageId, edit);
        context.pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _source,
      builder: (context, snapshot) {
        final source = snapshot.data;
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Cancel',
              icon: const Icon(LucideIcons.x),
              onPressed: () => context.pop(),
            ),
            title: Text('Crop & rotate', style: context.textTheme.titleLarge),
            actions: [
              IconButton(
                tooltip: 'Done',
                icon: const Icon(LucideIcons.check),
                onPressed: source == null || _saving
                    ? null
                    : () => _done(source),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: source == null
                    ? _Message(
                        loading:
                            snapshot.connectionState != ConnectionState.done,
                      )
                    : ExtendedImage.memory(
                        source,
                        fit: BoxFit.contain,
                        mode: ExtendedImageMode.editor,
                        // The editor needs the original bytes to crop.
                        cacheRawData: true,
                        initEditorConfigHandler: (state) => EditorConfig(
                          controller: _editor,
                          maxScale: 8,
                          cropRectPadding: const EdgeInsets.all(24),
                          hitTestSize: 24,
                          cropAspectRatio: _ratio,
                          // No auto-zoom after a corner is let go: the
                          // editor would zoom the picture so the frame
                          // fills the screen, leaving no room to drag a
                          // corner back out to the picture's edge. (This
                          // delay is that zoom's timer; the editor cancels
                          // it when it closes.) Pinch zooms by hand.
                          tickerDuration: const Duration(days: 1),
                          initCropRectType: InitCropRectType.imageRect,
                          cornerColor: context.colorScheme.primary,
                          lineColor: context.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
              ),
              _RatioBar(selected: _ratio, onSelected: _setRatio),
            ],
          ),
          bottomNavigationBar: _ToolBar(
            enabled: source != null && !_saving,
            onRotate: () => _editor.rotate(degree: 90, animation: true),
            onFlip: () => _editor.flip(animation: true),
            onReset: _reset,
          ),
        );
      },
    );
  }
}

/// While the picture loads (nothing), or when it could not be read.
class _Message extends StatelessWidget {
  const _Message({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) return const SizedBox.expand();
    return Center(
      child: Text(
        'Could not load this picture.',
        style: context.textTheme.bodyLarge?.copyWith(
          color: context.colors.textSecondary,
        ),
      ),
    );
  }
}

/// Free, A4, 1:1, 4:3, 16:9.
class _RatioBar extends StatelessWidget {
  const _RatioBar({required this.selected, required this.onSelected});

  final double? selected;
  final ValueChanged<double?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _ratios.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (label, ratio) = _ratios[index];
          return ChoiceChip(
            label: Text(label),
            selected: selected == ratio,
            showCheckmark: false,
            onSelected: (_) => onSelected(ratio),
          );
        },
      ),
    );
  }
}

/// Rotate, Flip, Reset: the same compact bar as Convert PDF.
class _ToolBar extends StatelessWidget {
  const _ToolBar({
    required this.enabled,
    required this.onRotate,
    required this.onFlip,
    required this.onReset,
  });

  final bool enabled;
  final VoidCallback onRotate;
  final VoidCallback onFlip;
  final VoidCallback onReset;

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
              _Tool(
                icon: LucideIcons.rotateCw,
                label: 'Rotate',
                onTap: enabled ? onRotate : null,
              ),
              _Tool(
                icon: LucideIcons.flipHorizontal2,
                label: 'Flip',
                onTap: enabled ? onFlip : null,
              ),
              _Tool(
                icon: LucideIcons.undo2,
                label: 'Reset',
                onTap: enabled ? onReset : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tool extends StatelessWidget {
  const _Tool({required this.icon, required this.label, required this.onTap});

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
