import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/app/router/app_routes.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/collage/domain/collage_layout.dart';
import 'package:proalbums/features/collage/domain/collage_rules.dart';
import 'package:proalbums/features/collage/presentation/collage_canvas.dart';
import 'package:proalbums/features/collage/presentation/collage_providers.dart';
import 'package:proalbums/features/collage/presentation/custom_color_sheet.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/images/media_thumbnail_image.dart';
import 'package:proalbums/features/gallery/presentation/providers/share_providers.dart';
import 'package:proalbums/features/gallery/presentation/viewer/providers/viewer_providers.dart';
import 'package:proalbums/shared/widgets/app_snack_bar.dart';
import 'package:proalbums/shared/widgets/confirm_dialog.dart';

enum _Mode { minimal, stitch }

enum _Panel { layout, borders, background, ratio }

/// Grid > Collage (2–9 pictures), like the system gallery:
///  - Minimal: Layout (layouts for this many pictures + Free), Borders
///    (Rounded corner, Margin, Padding), Background (colours), Ratio;
///  - Stitch: the pictures one under the other in one long picture;
///  - tap a picture: Rotate, Vertical, Horizontal (mirror), Replace, Filters;
///    drag / pinch it inside its cell, long press + drag onto another cell to
///    swap, drag the line between cells to resize;
///  - Save (Pictures/Collage = the "Collage" album) pops with the new id
///    (the caller opens it in the viewer); Share saves, then shares;
///  - X / Back with changes: "Discard changes?".
class CollagePage extends ConsumerStatefulWidget {
  const CollagePage({required this.items, super.key});

  final List<MediaItem> items;

  @override
  ConsumerState<CollagePage> createState() => _CollagePageState();
}

class _CollagePageState extends ConsumerState<CollagePage> {
  late List<MediaItem> _items = [...widget.items];
  late List<CollagePicture> _pictures = [
    for (final _ in widget.items) const CollagePicture(),
  ];
  late final List<CollageNode> _layouts = collageLayoutsFor(
    widget.items.length,
  );

  /// The layout chosen (null = Free) and the one shown (its lines may have
  /// been moved).
  int? _layoutIndex = 0;
  late CollageNode _tree = _layouts.first;
  late List<FreePicture> _free = freeStartFor(widget.items.length);

  _Mode _mode = _Mode.minimal;
  _Panel _panel = _Panel.layout;
  double _corner = CollageRules.defaultCorner;
  double _margin = CollageRules.defaultMargin;
  double _padding = CollageRules.defaultPadding;
  Color _background = collageBackgrounds.first;

  /// Background > picture: shown behind everything instead of the colour.
  MediaItem? _backgroundItem;
  CollageRatio _ratio = CollageRatio.threeFour;
  int? _selected;

  bool _changed = false;
  bool _saving = false;

  /// The last save, reused by Share while nothing changed.
  String? _savedId;

  final GlobalKey _canvasKey = GlobalKey();

  late final int _pictureSize = CollageRules.pictureSizeFor(
    widget.items.length,
  );

  ImageProvider _imageOf(MediaItem item) => MediaThumbnailImage(
    id: item.id,
    size: _pictureSize,
    load: (id, size) async {
      final result = await ref.read(loadDisplayImageUseCaseProvider)(
        id: id,
        maxLongEdge: size,
      );
      return result.fold((failure) => null, (bytes) => bytes);
    },
  );

  double _aspectOf(MediaItem item) =>
      item.height <= 0 ? 1 : item.width / item.height;

  void _edit(VoidCallback change) {
    setState(() {
      change();
      _changed = true;
      _savedId = null;
    });
  }

  // --- the picture toolbar ----------------------------------------------------

  void _changeSelected(CollagePicture Function(CollagePicture) change) {
    final slot = _selected;
    if (slot == null) return;
    _edit(() => _pictures[slot] = change(_pictures[slot]));
  }

  Future<void> _replace() async {
    final slot = _selected;
    if (slot == null) return;
    final picked = await context.push<List<MediaItem>>(
      AppRoutes.pickItemsWith(max: 1, imagesOnly: true),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    _edit(() {
      _items = [..._items]..[slot] = picked.first;
      _pictures = [..._pictures]..[slot] = const CollagePicture();
    });
  }

  /// Background > rainbow: the collage follows the colour live; X puts the
  /// old background back.
  Future<void> _pickCustomColor() async {
    final oldColor = _background;
    final oldItem = _backgroundItem;
    final picked = await showCustomColorSheet(
      context,
      initial: _background,
      onChanged: (color) => _edit(() {
        _background = color;
        _backgroundItem = null;
      }),
    );
    if (picked == null && mounted) {
      setState(() {
        _background = oldColor;
        _backgroundItem = oldItem;
      });
    }
  }

  /// Background > picture: any picture from the gallery, behind the collage
  /// (not blurred, like the system gallery).
  Future<void> _pickBackgroundPicture() async {
    final picked = await context.push<List<MediaItem>>(
      AppRoutes.pickItemsWith(max: 1, imagesOnly: true),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    _edit(() => _backgroundItem = picked.first);
  }

  Future<void> _chooseFilter() async {
    final slot = _selected;
    if (slot == null) return;
    await showModalBottomSheet<void>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => _FilterStrip(
        image: _imageOf(_items[slot]),
        current: _pictures[slot].filter,
        onPick: (filter) =>
            _changeSelected((picture) => picture.copyWith(filter: filter)),
      ),
    );
  }

  void _swap(int from, int to) => _edit(() {
    _items = [..._items];
    _pictures = [..._pictures];
    final item = _items[from];
    _items[from] = _items[to];
    _items[to] = item;
    final picture = _pictures[from];
    _pictures[from] = _pictures[to];
    _pictures[to] = picture;
    _selected = to;
  });

  // --- saving -------------------------------------------------------------------

  Future<String?> _save() async {
    if (_savedId != null) return _savedId;
    setState(() {
      _saving = true;
      _selected = null;
    });
    final repository = ref.read(collageRepositoryProvider);
    String? id;
    try {
      if (_mode == _Mode.stitch) {
        id = await repository.stitch([
          for (final item in _items) item.id,
        ], width: 1080);
      } else {
        // Let the frame without the selection frame be drawn first.
        await WidgetsBinding.instance.endOfFrame;
        final boundary =
            _canvasKey.currentContext?.findRenderObject()
                as RenderRepaintBoundary?;
        if (boundary != null) {
          final size = boundary.size;
          final ratio =
              CollageRules.exportLongEdge / math.max(size.width, size.height);
          final image = await boundary.toImage(pixelRatio: ratio);
          final data = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          final width = image.width;
          final height = image.height;
          image.dispose();
          if (data != null) {
            id = await repository.saveRgba(
              data.buffer.asUint8List(),
              width: width,
              height: height,
            );
          }
        }
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (id != null) {
      _savedId = id;
      _changed = false;
    }
    return id;
  }

  Future<void> _saveAndClose() async {
    final toast = AppToast.of(context);
    final id = await _save();
    if (!mounted) return;
    if (id == null) {
      toast.show('Could not save the collage');
      return;
    }
    toast.show('Saved');
    context.pop(id);
  }

  Future<void> _share() async {
    final toast = AppToast.of(context);
    final id = await _save();
    if (!mounted) return;
    if (id == null) {
      toast.show('Could not save the collage');
      return;
    }
    final result = await ref.read(shareMediaUseCaseProvider)([id]);
    result.match(
      (failure) => toast.show('Could not share the collage'),
      (_) {},
    );
  }

  Future<void> _close() async {
    if (!_changed) {
      // Saved by Share and not changed since: the viewer can show it.
      context.pop(_savedId);
      return;
    }
    final discard = await showConfirmDialog(
      context,
      title: 'Discard changes?',
      confirmLabel: 'Discard',
    );
    if ((discard ?? false) && mounted) context.pop(_savedId);
  }

  // --- building -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final images = [for (final item in _items) _imageOf(item)];
    final aspects = [for (final item in _items) _aspectOf(item)];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_close());
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 48,
          leading: IconButton(
            tooltip: 'Close',
            icon: const Icon(LucideIcons.x),
            onPressed: _saving ? null : _close,
          ),
          actions: [
            IconButton(
              tooltip: 'Share',
              icon: const Icon(LucideIcons.squareArrowOutUpRight),
              onPressed: _saving ? null : _share,
            ),
            IconButton(
              tooltip: 'Save',
              icon: const Icon(LucideIcons.save),
              onPressed: _saving ? null : _saveAndClose,
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => _mode == _Mode.stitch
                    ? _stitchPreview(images, aspects, constraints)
                    : _canvasArea(images, aspects, constraints),
              ),
            ),
            if (_saving) const LinearProgressIndicator(minHeight: 2),
            _bottomPanel(),
          ],
        ),
      ),
    );
  }

  Widget _canvasArea(
    List<ImageProvider> images,
    List<double> aspects,
    BoxConstraints constraints,
  ) {
    // The collage as big as fits, in the chosen ratio.
    // Nearly edge to edge, like the system gallery.
    const pad = 8.0;
    final maxW = constraints.maxWidth - pad * 2;
    final maxH = constraints.maxHeight - pad * 2;
    final ratio = _ratio.value;
    final width = math.min(maxW, maxH * ratio);
    final size = Size(width, width / ratio);
    final look = CollageLook(
      size: size,
      background: _background,
      backgroundImage: _backgroundItem == null
          ? null
          : _imageOf(_backgroundItem!),
      corner: _corner,
      margin: _layoutIndex == null ? 0 : _margin,
      padding: _padding,
    );
    final showHandles = !_saving;

    final canvas = _layoutIndex == null
        ? CollageFreeCanvas(
            look: look,
            images: images,
            aspects: aspects,
            pictures: _pictures,
            free: _free,
            selected: _selected,
            onSelect: (slot) => setState(() => _selected = slot),
            onFree: (free) => _edit(() => _free = free),
            showHandles: showHandles,
          )
        : CollageGridCanvas(
            tree: _tree,
            look: look,
            images: images,
            aspects: aspects,
            pictures: _pictures,
            selected: _selected,
            onSelect: (slot) => setState(() => _selected = slot),
            onPicture: (slot, picture) =>
                _edit(() => _pictures = [..._pictures]..[slot] = picture),
            onSwap: _swap,
            onTree: (tree) => _edit(() => _tree = tree),
            showHandles: showHandles,
          );

    final offset = Offset(
      (constraints.maxWidth - size.width) / 2,
      (constraints.maxHeight - size.height) / 2,
    );

    // The toolbar goes just under the chosen picture (above it when there is
    // no room below), centred on it, never off the screen.
    Offset? toolbarAt;
    final selected = _selected;
    if (selected != null && !_saving) {
      Rect? rect;
      if (_layoutIndex == null) {
        for (final item in _free) {
          if (item.slot != selected) continue;
          final aspect = _pictures[selected].quarterTurns.isOdd
              ? 1 / aspects[selected]
              : aspects[selected];
          rect = freePictureRect(item, aspect, size);
        }
      } else {
        rect = collagePixelRects(_tree, look)[selected];
      }
      if (rect != null) {
        final onScreen = rect.shift(offset);
        const gap = 6.0;
        final below = onScreen.bottom + gap;
        final top = below + _PictureToolbar.height <= constraints.maxHeight
            ? below
            : math.max(0.0, onScreen.top - gap - _PictureToolbar.height);
        final left = (onScreen.center.dx - _PictureToolbar.width / 2)
            .clamp(
              8.0,
              math.max(8.0, constraints.maxWidth - _PictureToolbar.width - 8),
            )
            .toDouble();
        toolbarAt = Offset(
          left,
          math.min(top, constraints.maxHeight - _PictureToolbar.height),
        );
      }
    }

    return Stack(
      children: [
        // Tap outside the collage: nothing selected.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _selected = null),
          ),
        ),
        Positioned(
          left: offset.dx,
          top: offset.dy,
          child: RepaintBoundary(key: _canvasKey, child: canvas),
        ),
        if (toolbarAt != null)
          Positioned(
            left: toolbarAt.dx,
            top: toolbarAt.dy,
            child: Center(
              child: _PictureToolbar(
                onRotate: () => _changeSelected(
                  (picture) => picture.copyWith(
                    quarterTurns: (picture.quarterTurns + 1) % 4,
                    scale: 1,
                    offset: Offset.zero,
                  ),
                ),
                onVertical: () => _changeSelected(
                  (picture) => picture.copyWith(mirrorY: !picture.mirrorY),
                ),
                onHorizontal: () => _changeSelected(
                  (picture) => picture.copyWith(mirrorX: !picture.mirrorX),
                ),
                onReplace: _replace,
                onFilters: _chooseFilter,
              ),
            ),
          ),
      ],
    );
  }

  Widget _stitchPreview(
    List<ImageProvider> images,
    List<double> aspects,
    BoxConstraints constraints,
  ) {
    final width = math.min(constraints.maxWidth * 0.6, 320.0);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox(
          width: width,
          child: Column(
            children: [
              for (var i = 0; i < images.length; i++)
                AspectRatio(
                  aspectRatio: aspects[i],
                  child: Image(
                    image: images[i],
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomPanel() {
    return Material(
      color: context.colorScheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4),
            _TextTabs<_Mode>(
              values: _Mode.values,
              selected: _mode,
              label: (mode) => mode == _Mode.minimal ? 'Minimal' : 'Stitch',
              large: true,
              onSelect: (mode) => _edit(() {
                _mode = mode;
                _selected = null;
              }),
            ),
            if (_mode == _Mode.minimal) ...[
              _TextTabs<_Panel>(
                values: _Panel.values,
                selected: _panel,
                label: (panel) => switch (panel) {
                  _Panel.layout => 'Layout',
                  _Panel.borders => 'Borders',
                  _Panel.background => 'Background',
                  _Panel.ratio => 'Ratio',
                },
                onSelect: (panel) => setState(() => _panel = panel),
              ),
              SizedBox(height: 128, child: _panelBody()),
            ] else
              // Stitch has no options: only the tabs (no empty panel).
              const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _panelBody() {
    switch (_panel) {
      case _Panel.layout:
        return GridView.count(
          crossAxisCount: 5,
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: [
            _LayoutTile(
              selected: _layoutIndex == null,
              onTap: () => _edit(() {
                _layoutIndex = null;
                _selected = null;
              }),
              child: Text(
                'Free',
                style: context.textTheme.labelLarge?.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            ),
            for (final (index, layout) in _layouts.indexed)
              _LayoutTile(
                selected: _layoutIndex == index,
                onTap: () => _edit(() {
                  _layoutIndex = index;
                  _tree = layout;
                  // A new layout starts clean: every picture covers its
                  // cell again (no zoom / move left from before).
                  _pictures = [
                    for (final picture in _pictures)
                      picture.copyWith(scale: 1, offset: Offset.zero),
                  ];
                  _selected = null;
                }),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: CollageLayoutPreview(
                    tree: layout,
                    color: _layoutIndex == index
                        ? context.colorScheme.onSurface
                        : context.colors.textSecondary,
                  ),
                ),
              ),
          ],
        );
      case _Panel.borders:
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
          children: [
            _SliderRow(
              label: 'Rounded corner',
              value: _corner,
              onChanged: (value) => _edit(() => _corner = value),
            ),
            _SliderRow(
              label: 'Margin',
              value: _margin,
              onChanged: (value) => _edit(() => _margin = value),
            ),
            _SliderRow(
              label: 'Padding',
              value: _padding,
              onChanged: (value) => _edit(() => _padding = value),
            ),
          ],
        );
      case _Panel.background:
        return GridView.count(
          crossAxisCount: 5,
          padding: const EdgeInsets.fromLTRB(40, 8, 40, 8),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: [
            // Own colour (the rainbow), the ready ones, then a picture.
            _RainbowDot(
              selected:
                  _backgroundItem == null &&
                  !collageBackgrounds.contains(_background),
              onTap: _pickCustomColor,
            ),
            for (final color in collageBackgrounds)
              _ColorDot(
                color: color,
                selected: _backgroundItem == null && color == _background,
                onTap: () => _edit(() {
                  _background = color;
                  _backgroundItem = null;
                }),
              ),
            _PictureDot(
              selected: _backgroundItem != null,
              onTap: _pickBackgroundPicture,
            ),
          ],
        );
      case _Panel.ratio:
        return ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
          children: [
            for (final ratio in CollageRatio.values)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _RatioTile(
                  ratio: ratio,
                  selected: ratio == _ratio,
                  onTap: () => _edit(() => _ratio = ratio),
                ),
              ),
          ],
        );
    }
  }
}

/// Rotate · Vertical · Horizontal · Replace · Filters for the picture tapped.
class _PictureToolbar extends StatelessWidget {
  const _PictureToolbar({
    required this.onRotate,
    required this.onVertical,
    required this.onHorizontal,
    required this.onReplace,
    required this.onFilters,
  });

  final VoidCallback onRotate;
  final VoidCallback onVertical;
  final VoidCallback onHorizontal;
  final VoidCallback onReplace;
  final VoidCallback onFilters;

  static const double _button = 54;

  /// Its fixed size (the page places it next to the chosen picture).
  static const double width = _button * 5 + 8;
  static const double height = 50;

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, String label, VoidCallback onTap) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: _button,
        height: height,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.mediaBadgeText, size: 18),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: context.textTheme.labelSmall?.copyWith(
                color: AppColors.mediaBadgeText,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );

    return Material(
      color: AppColors.mediaScrimTop,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            button(LucideIcons.rotateCw, 'Rotate', onRotate),
            button(LucideIcons.flipVertical2, 'Vertical', onVertical),
            button(LucideIcons.flipHorizontal2, 'Horizontal', onHorizontal),
            button(LucideIcons.arrowLeftRight, 'Replace', onReplace),
            button(LucideIcons.blend, 'Filters', onFilters),
          ],
        ),
      ),
    );
  }
}

/// The filters for the tapped picture, each shown on it.
class _FilterStrip extends StatefulWidget {
  const _FilterStrip({
    required this.image,
    required this.current,
    required this.onPick,
  });

  final ImageProvider image;
  final CollageFilter current;
  final ValueChanged<CollageFilter> onPick;

  @override
  State<_FilterStrip> createState() => _FilterStripState();
}

class _FilterStripState extends State<_FilterStrip> {
  late CollageFilter _current = widget.current;

  @override
  Widget build(BuildContext context) {
    final primary = context.colorScheme.primary;
    return SafeArea(
      child: SizedBox(
        height: 136,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(16),
          children: [
            for (final filter in CollageFilter.values)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _current = filter);
                    widget.onPick(filter);
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: filter == _current
                                ? primary
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: ColorFiltered(
                            colorFilter: filter.matrix == null
                                ? const ColorFilter.mode(
                                    Colors.transparent,
                                    BlendMode.dst,
                                  )
                                : ColorFilter.matrix(filter.matrix!),
                            child: Image(
                              image: widget.image,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(filter.label, style: context.textTheme.labelSmall),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Text tabs with an underline under the chosen one.
class _TextTabs<T> extends StatelessWidget {
  const _TextTabs({
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelect,
    this.large = false,
  });

  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onSelect;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final style = large
        ? context.textTheme.titleMedium
        : context.textTheme.bodyMedium;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final value in values)
          InkWell(
            onTap: () => onSelect(value),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label(value),
                    style: style?.copyWith(
                      color: value == selected
                          ? context.colorScheme.onSurface
                          : context.colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 3,
                    width: large && value == selected ? 36 : 0,
                    decoration: BoxDecoration(
                      color: context.colorScheme.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _LayoutTile extends StatelessWidget {
  const _LayoutTile({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: selected
            ? BorderSide(color: context.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(child: child),
      ),
    );
  }
}

/// One line: name, slider, value (compact, so the collage gets the room).
class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          SizedBox(
            width: 112,
            child: Text(label, style: context.textTheme.bodyMedium),
          ),
          Expanded(
            child: Slider(value: value, max: 100, onChanged: onChanged),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '${value.round()}',
              textAlign: TextAlign.end,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? context.colorScheme.primary
                : context.colors.dividerSubtle,
            width: selected ? 3 : 1,
          ),
        ),
      ),
    );
  }
}

/// Background > own colour: a rainbow dot.
class _RainbowDot extends StatelessWidget {
  const _RainbowDot({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(
            colors: [
              for (var h = 0; h <= 360; h += 60)
                HSVColor.fromAHSV(1, h.toDouble(), 0.45, 1).toColor(),
            ],
          ),
          border: Border.all(
            color: selected
                ? context.colorScheme.primary
                : context.colors.dividerSubtle,
            width: selected ? 3 : 1,
          ),
        ),
      ),
    );
  }
}

/// Background > a picture from the gallery.
class _PictureDot extends StatelessWidget {
  const _PictureDot({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: context.colorScheme.surfaceContainerHighest,
          border: Border.all(
            color: selected
                ? context.colorScheme.primary
                : context.colors.dividerSubtle,
            width: selected ? 3 : 1,
          ),
        ),
        child: Icon(LucideIcons.image, color: context.colorScheme.onSurface),
      ),
    );
  }
}

class _RatioTile extends StatelessWidget {
  const _RatioTile({
    required this.ratio,
    required this.selected,
    required this.onTap,
  });

  final CollageRatio ratio;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? context.colorScheme.onSurface
        : context.colors.textSecondary;
    // The little frame: its longer side 24.
    final frame = ratio.value >= 1
        ? Size(24, 24 / ratio.value)
        : Size(24 * ratio.value, 24);
    return SizedBox(
      width: 76,
      child: _LayoutTile(
        selected: selected,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: frame.width,
              height: frame.height,
              decoration: BoxDecoration(
                border: Border.all(color: color, width: 2),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              ratio.label,
              style: context.textTheme.labelLarge?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
