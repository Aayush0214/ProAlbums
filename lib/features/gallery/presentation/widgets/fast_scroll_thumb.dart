import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_geometry.dart';

/// The draggable scroll handle on the right edge, with a month bubble.
///
/// It appears while the list scrolls (and disappears after a moment), and can
/// be dragged to jump through thousands of photos quickly.
///
/// Only THIS small widget rebuilds when the scroll position changes.
class FastScrollThumb extends StatefulWidget {
  const FastScrollThumb({
    required this.controller,
    required this.geometry,
    required this.viewportHeight,
    required this.reversed,
    required this.topInset,
    required this.bottomInset,
    required this.labelAt,
    super.key,
  });

  final ScrollController controller;
  final GalleryGeometry geometry;
  final double viewportHeight;

  /// "Newest at the bottom": the list is reversed, offset 0 is the bottom.
  final bool reversed;

  /// Free space above/below the handle's track (app bar, bottom bar).
  final double topInset;
  final double bottomInset;

  /// Text for the bubble: the month at a top-down offset.
  final String? Function(double displayOffset) labelAt;

  @override
  State<FastScrollThumb> createState() => _FastScrollThumbState();
}

class _FastScrollThumbState extends State<FastScrollThumb> {
  static const double _thumbHeight = 48;
  static const double _touchWidth = 36;
  static const Duration _hideDelay = Duration(milliseconds: 1400);

  bool _visible = false;
  bool _dragging = false;
  double _dragFraction = 0;
  double _lastOffset = 0;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(FastScrollThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    _hideTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (!widget.controller.hasClients) return;
    final offset = widget.controller.offset;
    if (offset == _lastOffset) return;
    _lastOffset = offset;
    _show();
  }

  void _show() {
    if (!_visible && mounted) setState(() => _visible = true);
    _hideTimer?.cancel();
    if (!_dragging) {
      _hideTimer = Timer(_hideDelay, () {
        if (mounted && !_dragging) setState(() => _visible = false);
      });
    }
  }

  double get _track => widget.viewportHeight -
      widget.topInset -
      widget.bottomInset -
      _thumbHeight;

  /// 0 = top of the content, 1 = bottom (top-down, whatever the list order).
  double _fractionOf(ScrollPosition position) {
    final max = position.maxScrollExtent;
    if (max <= 0) return 0;
    final f = (position.pixels / max).clamp(0.0, 1.0);
    return widget.reversed ? 1 - f : f;
  }

  void _jumpToFraction(double fraction) {
    final position = widget.controller.position;
    final f = widget.reversed ? 1 - fraction : fraction;
    widget.controller.jumpTo(
      (f * position.maxScrollExtent).clamp(0.0, position.maxScrollExtent),
    );
  }

  void _onDragStart(DragStartDetails details) {
    _dragFraction = _fractionOf(widget.controller.position);
    HapticFeedback.selectionClick();
    setState(() => _dragging = true);
    _show();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_track <= 0) return;
    _dragFraction = (_dragFraction + details.delta.dy / _track).clamp(0.0, 1.0);
    _jumpToFraction(_dragFraction);
  }

  void _onDragEnd([Object? _]) {
    setState(() => _dragging = false);
    _show();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        if (!widget.controller.hasClients || _track <= 0) {
          return const SizedBox.shrink();
        }
        final position = widget.controller.position;
        // On the very first build the list has not been laid out yet, so its
        // size is unknown (reading it would crash). Check again next frame.
        if (!position.hasContentDimensions) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() {});
          });
          return const SizedBox.shrink();
        }
        // Nothing to jump through when everything fits on one screen.
        if (position.maxScrollExtent < widget.viewportHeight) {
          return const SizedBox.shrink();
        }

        final fraction = _dragging ? _dragFraction : _fractionOf(position);
        final top = widget.topInset + fraction * _track;
        final show = _visible || _dragging;
        final scheme = Theme.of(context).colorScheme;

        String? label;
        if (_dragging) {
          label = widget.labelAt(
            widget.geometry.displayOffsetFor(position.pixels, widget.viewportHeight),
          );
        }

        return Stack(
          children: [
            Positioned(
              top: top,
              right: 0,
              child: IgnorePointer(
                ignoring: !show,
                child: AnimatedOpacity(
                  opacity: show ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (label != null)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.inverseSurface,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            label,
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: scheme.onInverseSurface,
                                ),
                          ),
                        ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onVerticalDragStart: _onDragStart,
                        onVerticalDragUpdate: _onDragUpdate,
                        onVerticalDragEnd: _onDragEnd,
                        onVerticalDragCancel: _onDragEnd,
                        child: SizedBox(
                          width: _touchWidth,
                          height: _thumbHeight,
                          child: Align(
                            alignment: Alignment.centerRight,
                            // SOLID colour + light outline + shadow, so the
                            // handle stays visible on dark AND bright photos
                            // (a see-through handle fades into the picture).
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              width: _dragging ? 26 : 8,
                              height: _thumbHeight,
                              margin: const EdgeInsets.only(right: 3),
                              decoration: BoxDecoration(
                                color: _dragging
                                    ? scheme.primary
                                    : scheme.inverseSurface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  width: 1,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black38,
                                    blurRadius: 6,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: _dragging
                                  ? Icon(
                                      Icons.unfold_more_rounded,
                                      size: 20,
                                      color: scheme.onPrimary,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
