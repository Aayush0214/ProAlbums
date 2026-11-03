import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_geometry.dart';
import 'package:proalbums/features/gallery/presentation/providers/drag_selection.dart';
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
    required this.items,
    required this.child,
    this.enabled = true,
    super.key,
  });

  /// false while the user is pinching to zoom.
  final bool enabled;

  final ScrollController controller;
  final GalleryGeometry geometry;
  final double viewportHeight;

  /// The items of the grid in DISPLAY order (the same list the rows were cut
  /// from), so ANY grid can use drag select, not only the Photos tab.
  final List<MediaItem> items;
  final Widget child;

  @override
  ConsumerState<DragSelectGestures> createState() => _DragSelectGesturesState();
}

class _DragSelectGesturesState extends ConsumerState<DragSelectGestures>
    with SingleTickerProviderStateMixin {
  static const double _edgeZone = 80;

  /// Top auto-scroll speed (finger at the very edge). Same as the old
  /// 18 px every 16 ms, but per second, so it is equally fast at 60 and 120 Hz.
  static const double _maxScrollPerSecond = 1125;

  // Fingers on the screen right now. Two fingers = a pinch, NOT a selection.
  int _pointers = 0;

  Set<String> _base = const <String>{};
  int _anchor = 0;
  int _current = -1;
  bool _select = true;
  bool _dragging = false;
  Offset _lastPosition = Offset.zero;

  // Auto-scroll runs on a Ticker: one step per screen refresh (120 per second
  // on a 120 Hz screen). A Timer of 16 ms capped it at 60 steps per second,
  // so the grid moved at 60 fps while drag-selecting. It only runs while the
  // finger is in an edge zone, so a drag in the middle draws no extra frames.
  late final Ticker _autoScroll = createTicker(_tick);
  Duration _lastTick = Duration.zero;

  @override
  void dispose() {
    _autoScroll.dispose();
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
    final items = widget.items;
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
    _updateAutoScroll();
  }

  void _onMove(LongPressMoveUpdateDetails details) {
    if (!_dragging || _pointers > 1) return;
    _lastPosition = details.localPosition;
    final index = _indexAt(_lastPosition);
    if (index != null) _applyUpTo(index);
    _updateAutoScroll();
  }

  void _onEnd() {
    _dragging = false;
    _updateAutoScroll();
  }

  /// Starts the ticker when the finger enters an edge zone, stops it when
  /// it leaves (or the drag ends).
  void _updateAutoScroll() {
    final needed = _dragging && _edgeSpeed() != 0;
    if (needed && !_autoScroll.isActive) {
      _lastTick = Duration.zero;
      _autoScroll.start();
    } else if (!needed && _autoScroll.isActive) {
      _autoScroll.stop();
    }
  }

  /// Pixels per second, + = towards the bottom of the content. 0 outside
  /// the edge zones.
  double _edgeSpeed() {
    final y = _lastPosition.dy;
    if (y < _edgeZone) {
      return -_maxScrollPerSecond *
          ((_edgeZone - y) / _edgeZone).clamp(0.0, 1.0);
    }
    if (y > widget.viewportHeight - _edgeZone) {
      return _maxScrollPerSecond *
          ((y - (widget.viewportHeight - _edgeZone)) / _edgeZone)
              .clamp(0.0, 1.0);
    }
    return 0;
  }

  void _applyUpTo(int index) {
    if (index == _current) return;
    final items = widget.items;
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

  /// One auto-scroll step per screen refresh, while the finger is near the
  /// top or bottom edge. The step follows the real time since the last one.
  void _tick(Duration elapsed) {
    // Seconds since the last step. The first step of a run and long gaps
    // (a dropped frame) are capped at one 60 Hz frame, so it never leaps.
    final seconds = math.min(
      (elapsed - _lastTick).inMicroseconds / 1e6,
      1 / 60,
    );
    final first = _lastTick == Duration.zero;
    _lastTick = elapsed;
    if (first) return;
    if (!_dragging || !widget.controller.hasClients) return;

    final speed = _edgeSpeed() * seconds;
    if (speed == 0) return;

    final position = widget.controller.position;
    // A reversed list counts its offset from the bottom.
    final delta = widget.geometry.reversed ? -speed : speed;
    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (target == position.pixels) {
      // At the end of the list: nothing to scroll. Moving the finger
      // starts it again (see _onMove).
      _autoScroll.stop();
      return;
    }
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
