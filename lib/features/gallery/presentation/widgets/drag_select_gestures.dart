import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_geometry.dart';
import 'package:proalbums/features/gallery/presentation/providers/drag_selection.dart';
import 'package:proalbums/features/gallery/presentation/providers/gallery_rows_provider.dart';
import 'package:proalbums/features/gallery/presentation/providers/photos_selection_controller.dart';

/// Long press a photo, then slide the finger: every photo between the start
/// and the finger is selected (or unselected, if you started on a selected
/// one). Near the top/bottom edge the grid scrolls by itself.
///
/// Normal vertical drags still just scroll: only a LONG press starts this.
class DragSelectGestures extends ConsumerStatefulWidget {
  const DragSelectGestures({
    required this.controller,
    required this.geometry,
    required this.viewportHeight,
    required this.child,
    this.enabled = true,
    super.key,
  });

  /// false while the user is pinching to zoom.
  final bool enabled;

  final ScrollController controller;
  final GalleryGeometry geometry;
  final double viewportHeight;
  final Widget child;

  @override
  ConsumerState<DragSelectGestures> createState() => _DragSelectGesturesState();
}

class _DragSelectGesturesState extends ConsumerState<DragSelectGestures> {
  static const double _edgeZone = 80;
  static const double _maxScrollPerTick = 18;

  // Fingers on the screen right now. Two fingers = a pinch, NOT a selection.
  int _pointers = 0;

  Set<String> _base = const <String>{};
  int _anchor = 0;
  int _current = -1;
  bool _select = true;
  bool _dragging = false;
  Offset _lastPosition = Offset.zero;
  Timer? _autoScroll;

  @override
  void dispose() {
    _autoScroll?.cancel();
    super.dispose();
  }

  int? _indexAt(Offset position) {
    if (!widget.controller.hasClients) return null;
    final top = widget.geometry.displayOffsetFor(
      widget.controller.offset,
      widget.viewportHeight,
    );
    return widget.geometry.itemIndexAt(top + position.dy, position.dx);
  }

  void _onStart(LongPressStartDetails details) {
    // A pinch often starts with one finger resting for half a second. That
    // is not a long press on a photo.
    if (!widget.enabled || _pointers > 1) return;
    final items = ref.read(photosDisplayItemsProvider);
    final index = _indexAt(details.localPosition);
    if (index == null || index >= items.length) return;

    final selection = ref.read(photosSelectionControllerProvider);
    _base = selection.active ? <String>{...selection.ids} : <String>{};
    _select = !(selection.active && selection.ids.contains(items[index].id));
    _anchor = index;
    _current = -1;
    _dragging = true;
    _lastPosition = details.localPosition;

    HapticFeedback.selectionClick();
    _applyUpTo(index);
    _autoScroll = Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _tick(),
    );
  }

  void _onMove(LongPressMoveUpdateDetails details) {
    if (!_dragging || _pointers > 1) return;
    _lastPosition = details.localPosition;
    final index = _indexAt(_lastPosition);
    if (index != null) _applyUpTo(index);
  }

  void _onEnd() {
    _dragging = false;
    _autoScroll?.cancel();
    _autoScroll = null;
  }

  void _applyUpTo(int index) {
    if (index == _current) return;
    final items = ref.read(photosDisplayItemsProvider);
    if (items.isEmpty) return;
    _current = math.min(index, items.length - 1);

    final next = dragSelection(
      base: _base,
      anchor: _anchor,
      current: _current,
      select: _select,
      idsBetween: (from, to) => [
        for (var i = from; i <= to; i++) items[i].id,
      ],
    );
    ref.read(photosSelectionControllerProvider.notifier).setIds(next);
  }

  /// Scrolls while the finger is near the top or bottom edge.
  void _tick() {
    if (!_dragging || !widget.controller.hasClients) return;

    final y = _lastPosition.dy;
    double speed = 0; // + = towards the bottom of the content
    if (y < _edgeZone) {
      speed = -_maxScrollPerTick * ((_edgeZone - y) / _edgeZone).clamp(0.0, 1.0);
    } else if (y > widget.viewportHeight - _edgeZone) {
      speed = _maxScrollPerTick *
          ((y - (widget.viewportHeight - _edgeZone)) / _edgeZone).clamp(0.0, 1.0);
    }
    if (speed == 0) return;

    final position = widget.controller.position;
    // A reversed list counts its offset from the bottom.
    final delta = widget.geometry.reversed ? -speed : speed;
    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (target == position.pixels) return;
    widget.controller.jumpTo(target);

    final index = _indexAt(_lastPosition);
    if (index != null) _applyUpTo(index);
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointers++;
    // A second finger while dragging: it is a pinch now, stop selecting.
    if (_pointers > 1 && _dragging) _onEnd();
  }

  void _onPointerUp(PointerEvent event) {
    _pointers = math.max(0, _pointers - 1);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerUp,
      child: GestureDetector(
        onLongPressStart: _onStart,
        onLongPressMoveUpdate: _onMove,
        onLongPressEnd: (_) => _onEnd(),
        onLongPressCancel: _onEnd,
        child: widget.child,
      ),
    );
  }
}
