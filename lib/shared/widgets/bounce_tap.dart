import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Makes its child "feel pressed": it shrinks while the finger is down and
/// springs back (a small bounce) when let go, with a light haptic on tap.
/// Used by the cards that open a screen (Recently deleted, Internal storage).
class BounceTap extends StatefulWidget {
  const BounceTap({required this.onTap, required this.child, super.key});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<BounceTap> createState() => _BounceTapState();
}

class _BounceTapState extends State<BounceTap> {
  bool _pressed = false;

  void _setPressed({required bool value}) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(value: true),
      onTapUp: (_) => _setPressed(value: false),
      onTapCancel: () => _setPressed(value: false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1,
        duration: Duration(milliseconds: _pressed ? 90 : 320),
        curve: _pressed ? Curves.easeOut : Curves.elasticOut,
        child: widget.child,
      ),
    );
  }
}
