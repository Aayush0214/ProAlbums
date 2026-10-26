import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:proalbums/core/theme/app_colors.dart';

/// Frosted-glass wrapper (Stitch: "backdrop-blur" nav and top bars).
///
/// It only does the BLUR and a hairline border. The translucent color comes
/// from the child (for example NavigationBar's theme background), so we never
/// tint twice.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    required this.child,
    this.blurSigma = 24,
    super.key,
  });

  final Widget child;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: context.colors.glassBorder, width: 1)),
          ),
          child: child,
        ),
      ),
    );
  }
}
