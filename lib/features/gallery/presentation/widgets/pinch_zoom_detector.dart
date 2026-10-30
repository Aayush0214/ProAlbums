import 'package:flutter/widgets.dart';

/// Detects a two-finger pinch around [child] WITHOUT joining the gesture arena,
/// so one-finger scrolling and taps on the child keep working normally.
///
/// Every time the fingers move apart (or together) by about 25%, one zoom step
/// is reported, so a long pinch can go over several zoom levels.
class PinchZoomDetector extends StatefulWidget {
  const PinchZoomDetector({
    required this.child,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onPinchActiveChanged,
    super.key,
  });

  final Widget child;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  /// true while two fingers are down. The list stops scrolling meanwhile.
  final ValueChanged<bool> onPinchActiveChanged;

  @override
  State<PinchZoomDetector> createState() => _PinchZoomDetectorState();
}

class _PinchZoomDetectorState extends State<PinchZoomDetector> {
  static const double _zoomInRatio = 1.25;
  static const double _zoomOutRatio = 0.8;

  final Map<int, Offset> _pointers = <int, Offset>{};
  double? _baseline;
  bool _active = false;

  double _distance() {
    final points = _pointers.values.take(2).toList();
    return (points[0] - points[1]).distance;
  }

  void _setActive({required bool active}) {
    if (_active == active) return;
    _active = active;
    widget.onPinchActiveChanged(active);
  }

  void _onDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.position;
    if (_pointers.length == 2) {
      _baseline = _distance();
      _setActive(active: true);
    }
  }

  void _onMove(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.position;

    final baseline = _baseline;
    if (_pointers.length != 2 || baseline == null || baseline <= 0) return;

    final distance = _distance();
    final ratio = distance / baseline;
    if (ratio >= _zoomInRatio) {
      widget.onZoomIn();
      _baseline = distance;
    } else if (ratio <= _zoomOutRatio) {
      widget.onZoomOut();
      _baseline = distance;
    }
  }

  void _onUpOrCancel(PointerEvent event) {
    _pointers.remove(event.pointer);
    if (_pointers.length < 2) {
      _baseline = null;
      _setActive(active: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: _onUpOrCancel,
      onPointerCancel: _onUpOrCancel,
      child: widget.child,
    );
  }
}
