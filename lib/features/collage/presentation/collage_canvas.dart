import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/collage/domain/collage_layout.dart';
import 'package:proalbums/features/collage/domain/collage_rules.dart';

/// Everything the canvas draws, decided by the page.
final class CollageLook {
  const CollageLook({
    required this.size,
    required this.background,
    required this.corner,
    required this.margin,
    required this.padding,
    this.backgroundImage,
  });

  /// The collage on screen, in logical pixels.
  final Size size;
  final Color background;

  /// A picture behind everything (Background > picture), covering the
  /// collage; null = the colour.
  final ImageProvider? backgroundImage;

  /// Slider values (0–100), see [CollageRules.unitOfWidth].
  final double corner;
  final double margin;
  final double padding;

  double px(double value) => value * CollageRules.unitOfWidth * size.width;
}

/// Where each cell of [tree] is on a canvas of [look] (pixels): the outer
/// edge is the Margin, the gap between cells the Padding.
Map<int, Rect> collagePixelRects(CollageNode tree, CollageLook look) {
  final content = _content(look);
  final half = look.px(look.padding) / 2;
  return {
    for (final entry in collageCellRects(tree).entries)
      entry.key: _map(entry.value, content).deflate(half),
  };
}

Rect _content(CollageLook look) {
  final edge = math.max(0.0, look.px(look.margin) - look.px(look.padding) / 2);
  return (Offset.zero & look.size).deflate(edge);
}

Rect _map(Rect unit, Rect area) => Rect.fromLTRB(
  area.left + unit.left * area.width,
  area.top + unit.top * area.height,
  area.left + unit.right * area.width,
  area.top + unit.bottom * area.height,
);

/// The smallest zoom of a picture of [aspect] in [box]: the whole picture
/// visible (1 = covering the box).
double minPictureScale(Size box, double aspect) {
  final boxAspect = box.width / box.height;
  return boxAspect > aspect ? aspect / boxAspect : boxAspect / aspect;
}

/// Where a picture of [aspect] goes in [box]: scale 1 covers the box, less
/// shows more of the picture (down to all of it, [minPictureScale]), more
/// zooms in; [offset] (in box sizes) moves it, never further than its edges
/// (or, when it is smaller than the box, than the box's edges).
Rect coverRect({
  required Size box,
  required double aspect,
  required double scale,
  required Offset offset,
}) {
  if (box.width <= 0 || box.height <= 0 || aspect <= 0) return Rect.zero;
  final boxAspect = box.width / box.height;
  final fitted = scale.clamp(minPictureScale(box, aspect), 8.0);
  final width = boxAspect > aspect
      ? box.width * fitted
      : box.height * fitted * aspect;
  final height = width / aspect;
  // Never negative (rounding once made it -0.0000001, and clamp threw).
  final maxDx = ((width - box.width) / 2).abs();
  final maxDy = ((height - box.height) / 2).abs();
  final dx = (offset.dx * box.width).clamp(-maxDx, maxDx);
  final dy = (offset.dy * box.height).clamp(-maxDy, maxDy);
  return Rect.fromLTWH(
    (box.width - width) / 2 + dx,
    (box.height - height) / 2 + dy,
    width,
    height,
  );
}

/// One picture placed in a box (see [coverRect]), turned / mirrored /
/// filtered.
class CollagePictureView extends StatelessWidget {
  const CollagePictureView({
    required this.image,
    required this.aspect,
    required this.picture,
    required this.box,
    super.key,
  });

  final ImageProvider image;

  /// The picture's width / height as stored (before its quarter turns).
  final double aspect;
  final CollagePicture picture;
  final Size box;

  @override
  Widget build(BuildContext context) {
    final placed = coverRect(
      box: box,
      aspect: picture.quarterTurns.isOdd ? 1 / aspect : aspect,
      scale: picture.scale,
      offset: picture.offset,
    );
    Widget child = Transform.flip(
      flipX: picture.mirrorX,
      flipY: picture.mirrorY,
      child: RotatedBox(
        quarterTurns: picture.quarterTurns,
        child: Image(
          image: image,
          fit: BoxFit.fill,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        ),
      ),
    );
    final matrix = picture.filter.matrix;
    if (matrix != null) {
      child = ColorFiltered(
        colorFilter: ColorFilter.matrix(matrix),
        child: child,
      );
    }
    return ClipRect(
      child: Stack(
        clipBehavior: Clip.none,
        children: [Positioned.fromRect(rect: placed, child: child)],
      ),
    );
  }
}

/// The frame around the chosen picture: thick, in the accent colour, with a
/// thin light line inside so it shows on dark and light pictures.
class _SelectionFrame extends StatelessWidget {
  const _SelectionFrame({required this.radius});

  final Radius radius;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: context.colorScheme.primary, width: 3),
          borderRadius: BorderRadius.all(radius),
        ),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.mediaBadgeText.withValues(alpha: 0.7),
              ),
              borderRadius: BorderRadius.all(radius),
            ),
          ),
        ),
      ),
    );
  }
}

/// The collage's background: the chosen picture (covering it) or colour.
Widget collageBackground(CollageLook look) => Positioned.fill(
  child: look.backgroundImage == null
      ? ColoredBox(color: look.background)
      : Image(
          image: look.backgroundImage!,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) =>
              ColoredBox(color: look.background),
        ),
);

/// The Minimal collage. ONE touch area for the whole collage (so two fingers
/// on two different pictures still make one pinch):
///  - single tap: choose / un-choose the picture under the finger;
///  - drag / pinch: moves / zooms the chosen picture if the gesture starts
///    on it, else the picture where the first finger came down; each cell
///    is white behind its picture (like the system gallery), so a picture
///    moved or zoomed out shows where the cell is;
///  - long press: the picture lifts and follows the finger, the cell under
///    it lights up; let go = the two pictures glide into each other's place;
///  - the lines between cells (on top) can be dragged.
class CollageGridCanvas extends StatefulWidget {
  const CollageGridCanvas({
    required this.tree,
    required this.look,
    required this.images,
    required this.aspects,
    required this.pictures,
    required this.selected,
    required this.onSelect,
    required this.onPicture,
    required this.onSwap,
    required this.onTree,
    required this.showHandles,
    super.key,
  });

  final CollageNode tree;
  final CollageLook look;
  final List<ImageProvider> images;
  final List<double> aspects;
  final List<CollagePicture> pictures;
  final int? selected;
  final ValueChanged<int?> onSelect;
  final void Function(int slot, CollagePicture picture) onPicture;
  final void Function(int from, int to) onSwap;
  final ValueChanged<CollageNode> onTree;

  /// Selection frame, swap highlight and line handles (off while saving).
  final bool showHandles;

  @override
  State<CollageGridCanvas> createState() => _CollageGridCanvasState();
}

class _CollageGridCanvasState extends State<CollageGridCanvas>
    with SingleTickerProviderStateMixin {
  int? _target;
  CollagePicture? _start;
  Offset _startFocal = Offset.zero;

  // Long press: the lifted picture, where the finger is, and where in the
  // cell it was grabbed.
  int? _dragFrom;
  int? _dragOver;
  Offset _finger = Offset.zero;
  Offset _grab = Offset.zero;

  // After a swap: both pictures glide from their old cell to the new one.
  late final AnimationController _glide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  int? _glideA;
  int? _glideB;
  Rect? _glideFromA;
  Rect? _glideFromB;

  @override
  void dispose() {
    _glide.dispose();
    super.dispose();
  }

  int? _slotAt(Offset point, Map<int, Rect> rects) {
    for (final entry in rects.entries) {
      if (entry.value.contains(point)) return entry.key;
    }
    return null;
  }

  double _aspect(int slot) {
    final aspect = widget.aspects[slot];
    return widget.pictures[slot].quarterTurns.isOdd ? 1 / aspect : aspect;
  }

  void _drop(Map<int, Rect> rects) {
    final from = _dragFrom;
    final to = _dragOver;
    setState(() {
      _dragFrom = null;
      _dragOver = null;
    });
    if (from == null || to == null || from == to) return;
    // The picture now in [to] came from [from] and the other way round.
    _glideA = to;
    _glideFromA = rects[from];
    _glideB = from;
    _glideFromB = rects[to];
    widget.onSwap(from, to);
    _glide.forward(from: 0);
  }

  /// A cell: white behind, its picture on top, rounded.
  Widget _cell(int slot, Size size, Radius radius) => ClipRRect(
    borderRadius: BorderRadius.all(radius),
    child: Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppColors.mediaBadgeText),
        CollagePictureView(
          image: widget.images[slot],
          aspect: widget.aspects[slot],
          picture: widget.pictures[slot],
          box: size,
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final look = widget.look;
    final rects = collagePixelRects(widget.tree, look);
    final radius = Radius.circular(look.px(look.corner));
    final content = _content(look);
    final dragFrom = _dragFrom;

    return SizedBox.fromSize(
      size: look.size,
      child: Stack(
        children: [
          collageBackground(look),
          for (final MapEntry(key: slot, value: rect) in rects.entries)
            AnimatedBuilder(
              animation: _glide,
              builder: (context, child) {
                // Gliding after a swap: from the old cell to this one.
                Rect? from;
                if (_glide.isAnimating) {
                  if (slot == _glideA) from = _glideFromA;
                  if (slot == _glideB) from = _glideFromB;
                }
                final t = Curves.easeOutCubic.transform(_glide.value);
                final shown = from == null ? rect : Rect.lerp(from, rect, t)!;
                return Positioned.fromRect(rect: shown, child: child!);
              },
              child: Opacity(
                // The lifted picture leaves a faint copy behind.
                opacity: dragFrom == slot ? 0.35 : 1,
                child: _cell(slot, rect.size, radius),
              ),
            ),
          if (widget.showHandles)
            for (final MapEntry(key: slot, value: rect) in rects.entries)
              if ((dragFrom == null && slot == widget.selected) ||
                  (dragFrom != null && _dragOver == slot && slot != dragFrom))
                Positioned.fromRect(
                  rect: rect,
                  child: _SelectionFrame(radius: radius),
                ),
          // The lifted picture, following the finger.
          if (dragFrom != null)
            Builder(
              builder: (context) {
                final rect = rects[dragFrom]!;
                final size = rect.size * 0.85;
                return Positioned(
                  left: _finger.dx - _grab.dx * 0.85,
                  top: _finger.dy - _grab.dy * 0.85,
                  width: size.width,
                  height: size.height,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.all(radius),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.mediaScrimTop,
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: Opacity(
                        opacity: 0.9,
                        child: _cell(dragFrom, size, radius),
                      ),
                    ),
                  ),
                );
              },
            ),
          // The one touch area.
          // Keyed: pictures / frames appearing before it must not make
          // Flutter rebuild it (that dropped the gesture in the middle of a
          // hold-and-drag swap).
          Positioned.fill(
            key: const ValueKey<String>('touch'),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                final slot = _slotAt(details.localPosition, rects);
                widget.onSelect(
                  slot == null || slot == widget.selected ? null : slot,
                );
              },
              onScaleStart: (details) {
                final selected = widget.selected;
                final point = details.localFocalPoint;
                _target = selected != null && rects[selected]!.contains(point)
                    ? selected
                    : _slotAt(point, rects);
                _start = _target == null ? null : widget.pictures[_target!];
                _startFocal = point;
              },
              onScaleUpdate: (details) {
                final slot = _target;
                final start = _start;
                if (slot == null || start == null) return;
                final rect = rects[slot]!;
                final moved = details.localFocalPoint - _startFocal;
                widget.onPicture(
                  slot,
                  start.copyWith(
                    scale: (start.scale * details.scale).clamp(
                      minPictureScale(rect.size, _aspect(slot)),
                      4.0,
                    ),
                    offset:
                        start.offset +
                        Offset(moved.dx / rect.width, moved.dy / rect.height),
                  ),
                );
              },
              onScaleEnd: (_) {
                final slot = _target;
                _target = null;
                _start = null;
                if (slot == null) return;
                // Keep only the movement that is really used.
                final rect = rects[slot]!;
                final picture = widget.pictures[slot];
                final placed = coverRect(
                  box: rect.size,
                  aspect: _aspect(slot),
                  scale: picture.scale,
                  offset: picture.offset,
                );
                final centre =
                    placed.center - Offset(rect.width / 2, rect.height / 2);
                widget.onPicture(
                  slot,
                  picture.copyWith(
                    offset: Offset(
                      centre.dx / rect.width,
                      centre.dy / rect.height,
                    ),
                  ),
                );
              },
              onLongPressStart: (details) {
                final slot = _slotAt(details.localPosition, rects);
                if (slot == null) return;
                setState(() {
                  _dragFrom = slot;
                  _dragOver = slot;
                  _finger = details.localPosition;
                  _grab = details.localPosition - rects[slot]!.topLeft;
                });
              },
              onLongPressMoveUpdate: (details) {
                if (_dragFrom == null) return;
                setState(() {
                  _finger = details.localPosition;
                  _dragOver = _slotAt(details.localPosition, rects);
                });
              },
              onLongPressEnd: (_) => _drop(rects),
              onLongPressCancel: () => setState(() {
                _dragFrom = null;
                _dragOver = null;
              }),
            ),
          ),
          // The lines between cells: on top, so they win where they are.
          if (widget.showHandles && dragFrom == null)
            for (final line in collageDividers(widget.tree))
              _DividerHandle(
                line: line,
                area: content,
                onDrag: (delta) {
                  final span = collageSplitSpan(widget.tree, line.path);
                  final share = line.sideBySide
                      ? delta.dx / content.width
                      : delta.dy / content.height;
                  widget.onTree(
                    moveCollageDivider(widget.tree, line.path, share / span),
                  );
                },
              ),
        ],
      ),
    );
  }
}

/// A thin strip along a line between cells; dragging it moves the line.
class _DividerHandle extends StatelessWidget {
  const _DividerHandle({
    required this.line,
    required this.area,
    required this.onDrag,
  });

  final CollageDivider line;
  final Rect area;
  final ValueChanged<Offset> onDrag;

  static const double _thickness = 20;

  @override
  Widget build(BuildContext context) {
    final rect = _map(line.rect, area);
    final hit = line.sideBySide
        ? Rect.fromCenter(
            center: rect.center,
            width: _thickness,
            height: rect.height * 0.5,
          )
        : Rect.fromCenter(
            center: rect.center,
            width: rect.width * 0.5,
            height: _thickness,
          );
    return Positioned.fromRect(
      rect: hit,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) => onDrag(details.delta),
      ),
    );
  }
}

/// Where a Free picture is drawn (unturned box around its centre).
Rect freePictureRect(FreePicture item, double aspect, Size size) {
  final width = item.width * size.width;
  final height = width / aspect;
  return Rect.fromCenter(
    center: Offset(item.center.dx * size.width, item.center.dy * size.height),
    width: width,
    height: height,
  );
}

/// The Free collage: pictures anywhere. ONE touch area: single tap chooses
/// the picture on top under the finger; one / two fingers move, zoom and
/// turn the chosen picture if the gesture starts on it, else the picture on
/// top where the first finger came down (it comes to the front).
class CollageFreeCanvas extends StatefulWidget {
  const CollageFreeCanvas({
    required this.look,
    required this.images,
    required this.aspects,
    required this.pictures,
    required this.free,
    required this.selected,
    required this.onSelect,
    required this.onFree,
    required this.showHandles,
    super.key,
  });

  final CollageLook look;
  final List<ImageProvider> images;
  final List<double> aspects;
  final List<CollagePicture> pictures;

  /// In drawing order (last = on top).
  final List<FreePicture> free;
  final int? selected;
  final ValueChanged<int?> onSelect;
  final ValueChanged<List<FreePicture>> onFree;
  final bool showHandles;

  @override
  State<CollageFreeCanvas> createState() => _CollageFreeCanvasState();
}

class _CollageFreeCanvasState extends State<CollageFreeCanvas> {
  FreePicture? _start;
  Offset _startFocal = Offset.zero;

  double _aspectOf(int slot) {
    final aspect = widget.aspects[slot];
    return widget.pictures[slot].quarterTurns.isOdd ? 1 / aspect : aspect;
  }

  /// Is [point] on [item] (its turn taken into account)?
  bool _hits(FreePicture item, Offset point) {
    final rect = freePictureRect(item, _aspectOf(item.slot), widget.look.size);
    final local = point - rect.center;
    final cos = math.cos(-item.angle);
    final sin = math.sin(-item.angle);
    final unturned = Offset(
      local.dx * cos - local.dy * sin,
      local.dx * sin + local.dy * cos,
    );
    return unturned.dx.abs() <= rect.width / 2 &&
        unturned.dy.abs() <= rect.height / 2;
  }

  /// The picture on top under [point].
  FreePicture? _at(Offset point) {
    for (final item in widget.free.reversed) {
      if (_hits(item, point)) return item;
    }
    return null;
  }

  void _update(FreePicture changed) {
    widget.onFree([
      for (final item in widget.free)
        if (item.slot != changed.slot) item,
      changed,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final look = widget.look;
    final size = look.size;
    final radius = Radius.circular(look.px(look.corner));

    return SizedBox.fromSize(
      size: size,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          collageBackground(look),
          for (final item in widget.free)
            Builder(
              builder: (context) {
                final picture = widget.pictures[item.slot];
                final rect = freePictureRect(item, _aspectOf(item.slot), size);
                return Positioned.fromRect(
                  rect: rect,
                  child: Transform.rotate(
                    angle: item.angle,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.all(radius),
                          child: CollagePictureView(
                            image: widget.images[item.slot],
                            aspect: widget.aspects[item.slot],
                            picture: picture.copyWith(
                              scale: 1,
                              offset: Offset.zero,
                            ),
                            box: rect.size,
                          ),
                        ),
                        if (widget.showHandles && widget.selected == item.slot)
                          _SelectionFrame(radius: radius),
                      ],
                    ),
                  ),
                );
              },
            ),
          Positioned.fill(
            key: const ValueKey<String>('touch'),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                final item = _at(details.localPosition);
                widget.onSelect(
                  item == null || item.slot == widget.selected
                      ? null
                      : item.slot,
                );
              },
              onScaleStart: (details) {
                final point = details.localFocalPoint;
                final selected = widget.selected;
                FreePicture? target;
                if (selected != null) {
                  for (final item in widget.free) {
                    if (item.slot == selected && _hits(item, point)) {
                      target = item;
                    }
                  }
                }
                target ??= _at(point);
                _start = target;
                _startFocal = point;
                if (target != null) _update(target);
              },
              onScaleUpdate: (details) {
                final start = _start;
                if (start == null) return;
                final moved = details.localFocalPoint - _startFocal;
                _update(
                  start.copyWith(
                    center:
                        start.center +
                        Offset(moved.dx / size.width, moved.dy / size.height),
                    width: (start.width * details.scale).clamp(0.12, 1.6),
                    angle: start.angle + details.rotation,
                  ),
                );
              },
              onScaleEnd: (_) => _start = null,
            ),
          ),
        ],
      ),
    );
  }
}

/// A small drawing of a layout for the Layout tab.
class CollageLayoutPreview extends StatelessWidget {
  const CollageLayoutPreview({
    required this.tree,
    required this.color,
    super.key,
  });

  final CollageNode tree;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Fills the tile (a CustomPaint with no child and no size is 0 × 0).
    return SizedBox.expand(
      child: CustomPaint(painter: _LayoutPainter(tree, color)),
    );
  }
}

class _LayoutPainter extends CustomPainter {
  _LayoutPainter(this.tree, this.color);

  final CollageNode tree;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (final unit in collageCellRects(tree).values) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          _map(unit, Offset.zero & size).deflate(1.5),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_LayoutPainter old) =>
      old.tree != tree || old.color != color;
}
