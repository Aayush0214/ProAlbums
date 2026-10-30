import 'package:flutter/material.dart';
import 'package:proalbums/core/theme/app_colors.dart';

/// "Glass" look for the bottom bar: a nearly opaque surface and a hairline
/// border.
///
/// It used to blur what is behind it (BackdropFilter). Measured on the real
/// phone, that blur doubled the number of slow frames while scrolling, because
/// the GPU has to re-blur the photos moving behind the bar on every frame.
/// A nearly opaque surface looks almost the same and costs nothing.
class GlassContainer extends StatelessWidget {
  const GlassContainer({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.94),
        border: Border(top: BorderSide(color: context.colors.glassBorder, width: 1)),
      ),
      child: child,
    );
  }
}
