import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// How a slideshow looks and moves. The viewer uses the defaults (like the
/// system gallery); later screens (For You memories) can pass their own.
@immutable
final class SlideshowOptions {
  const SlideshowOptions({
    this.slide = const Duration(seconds: 3),
    this.fade = const Duration(milliseconds: 800),
    // Same zoom speed Aayush liked with 2 s (0.25 over 3.6 s), over 4.6 s.
    this.zoomTo = 1.32,
    this.fit = BoxFit.contain,
  });

  /// How a picture fills the player: whole picture on a dark screen
  /// (contain, the viewer's slideshow) or filling a banner (cover, a
  /// person's page).
  final BoxFit fit;

  /// How long a picture stays fully on screen (between its fades).
  final Duration slide;

  /// The cross-fade: the new picture fades in WHILE the old one fades out.
  final Duration fade;

  /// A picture grows from 1 to this, evenly, for its whole time on screen
  /// (fade in + shown + fade out), so the movement never stops or jumps.
  final double zoomTo;
}

/// Pictures one after another on a dark screen: each one zooms in evenly
/// for its whole life on screen, and the next one cross-fades over it (the
/// old one fades out at the same time, so a wide picture after a tall one
/// leaves nothing of the old one behind). Knows nothing about the gallery:
/// it is given a count and a picture per index.
///
///  - the next picture is loaded while the current one is shown; if it is not
///    ready in time, the current one simply stays a little longer (never an
///    empty frame);
///  - [onIndex] tells which picture is on screen (the caller remembers it for
///    Back / tap);
///  - after the last picture has had its time, [onFinished] is called.
class SlideshowPlayer extends StatefulWidget {
  const SlideshowPlayer({
    required this.count,
    required this.imageAt,
    required this.onFinished,
    this.startIndex = 0,
    this.options = const SlideshowOptions(),
    this.onIndex,
    super.key,
  });

  final int count;
  final ImageProvider Function(int index) imageAt;
  final int startIndex;
  final SlideshowOptions options;
  final ValueChanged<int>? onIndex;
  final VoidCallback onFinished;

  @override
  State<SlideshowPlayer> createState() => _SlideshowPlayerState();
}

class _SlideshowPlayerState extends State<SlideshowPlayer> {
  late int _index = widget.startIndex.clamp(0, widget.count - 1);

  /// Pictures on screen, oldest first: normally one, two while fading.
  late final List<int> _onScreen = [_index];

  /// Pictures fading out (they leave [_onScreen] once fully gone).
  final Set<int> _leaving = {};

  Timer? _timer;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) => _show(_index));
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }

  /// Picture [index] is on screen: load the next one meanwhile, and move on
  /// when its time is up AND the next one is ready.
  void _show(int index) {
    widget.onIndex?.call(index);
    final hasNext = index + 1 < widget.count;
    final ready = hasNext
        ? precacheImage(widget.imageAt(index + 1), context, onError: (_, _) {})
        : Future<void>.value();
    final timeUp = Completer<void>();
    // Its own fade in + its time on screen.
    _timer = Timer(widget.options.fade + widget.options.slide, timeUp.complete);
    unawaited(
      Future.wait([ready, timeUp.future]).then((_) {
        if (_disposed || !mounted) return;
        if (!hasNext) {
          widget.onFinished();
          return;
        }
        setState(() {
          _leaving.add(index);
          _index = index + 1;
          _onScreen.add(_index);
        });
        _show(_index);
      }),
    );
  }

  void _gone(int index) {
    if (_disposed || !mounted) return;
    setState(() {
      _onScreen.remove(index);
      _leaving.remove(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Every picture keeps its key (and so its running zoom) for its whole
    // time on screen; the newest is on top.
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final index in _onScreen)
          _Slide(
            key: ValueKey(index),
            image: widget.imageAt(index),
            options: widget.options,
            leaving: _leaving.contains(index),
            // The very first picture is already there (no fade from black).
            fadeIn: index != widget.startIndex,
            // In, out, in, out…: a picture arrives at the size the one
            // before has reached, so their edges match in the cross-fade.
            zoomIn: (index - widget.startIndex).isEven,
            onGone: () => _gone(index),
          ),
      ],
    );
  }
}

/// One picture, fitted to the screen. ONE clock runs its whole life:
/// fade in → shown → (when told to leave) fade out; the zoom follows that
/// same clock evenly, so it never pauses or jumps.
class _Slide extends StatefulWidget {
  const _Slide({
    required this.image,
    required this.options,
    required this.leaving,
    required this.fadeIn,
    required this.zoomIn,
    required this.onGone,
    super.key,
  });

  final ImageProvider image;
  final SlideshowOptions options;
  final bool leaving;
  final bool fadeIn;

  /// true: 1 → [SlideshowOptions.zoomTo]; false: zoomTo → 1.
  final bool zoomIn;
  final VoidCallback onGone;

  @override
  State<_Slide> createState() => _SlideState();
}

class _SlideState extends State<_Slide> with TickerProviderStateMixin {
  late final SlideshowOptions _o = widget.options;

  /// Zoom: one even movement; [SlideshowOptions.zoomTo] is reached after
  /// fade in + shown + fade out. The clock runs twice that long at the same
  /// speed, so a picture that waits for a slow next one keeps moving.
  late final AnimationController _zoom = AnimationController(
    vsync: this,
    duration: (_o.fade * 2 + _o.slide) * 2,
  )..forward();

  late final Animation<double> _scale = _zoom.drive(
    _Zoom(zoomIn: widget.zoomIn, amount: _o.zoomTo - 1),
  );

  /// Opacity: up at the start, down when leaving.
  late final AnimationController _opacity = AnimationController(
    vsync: this,
    duration: _o.fade,
    value: widget.fadeIn ? 0 : 1,
  );

  /// The new picture comes up quickly, the old one stays up longer and goes
  /// at the end: together they always cover the screen (no dip to dark in
  /// the middle of the cross-fade).
  late final Animation<double> _eased = CurvedAnimation(
    parent: _opacity,
    curve: Curves.easeOut,
    reverseCurve: Curves.easeOut,
  );

  @override
  void initState() {
    super.initState();
    if (widget.fadeIn) _opacity.forward();
  }

  @override
  void didUpdateWidget(_Slide old) {
    super.didUpdateWidget(old);
    if (widget.leaving && !old.leaving) {
      // The zoom keeps going (to its end exactly as the fade ends, or a
      // little after when this picture had to wait for the next one).
      _opacity.reverse().whenComplete(() {
        if (mounted) widget.onGone();
      });
    }
  }

  @override
  void dispose() {
    _zoom.dispose();
    _opacity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _eased,
      child: ScaleTransition(
        scale: _scale,
        child: Image(
          image: widget.image,
          fit: _o.fit,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// A slide's size over its clock (0–1 = twice its planned life, see
/// [_SlideState._zoom]): even speed, [amount] per planned life. Zooming in
/// goes on growing if the slide has to wait; zooming out stops at 1, never
/// smaller (that would show dark edges).
class _Zoom extends Animatable<double> {
  const _Zoom({required this.zoomIn, required this.amount});

  final bool zoomIn;
  final double amount;

  @override
  double transform(double t) {
    // t covers twice the planned life.
    return slideZoomAt(zoomIn: zoomIn, amount: amount, life: t * 2);
  }
}

/// A slide's size at [life] (0 = it appears, 1 = the end of its planned time
/// on screen, more = it had to wait). Zooming in keeps growing; zooming out
/// stops at 1. One ends where the next starts: `slideZoomAt(zoomIn: true,
/// life: 1) == slideZoomAt(zoomIn: false, life: 0)`.
@visibleForTesting
double slideZoomAt({
  required bool zoomIn,
  required double amount,
  required double life,
}) => zoomIn ? 1 + amount * life : math.max(1, 1 + amount * (1 - life));
