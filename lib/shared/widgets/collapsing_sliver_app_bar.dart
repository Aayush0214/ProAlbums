import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:proalbums/core/theme/app_colors.dart';

/// Title sizes: big when the page is at the top, smaller once scrolled.
const double kTitleExpandedSize = 32;
const double kTitleCollapsedSize = 22;

/// How far the title has shrunk, 0 (big) .. 1 (small), for [fromTop] pixels
/// scrolled. Pure, so it is tested.
double collapseProgress(double fromTop, {double distance = 56}) =>
    (fromTop / distance).clamp(0.0, 1.0);

/// The title style at a given [progress]: only the size changes.
TextStyle collapsingTitleStyle(BuildContext context, double progress) =>
    context.textTheme.headlineLarge!.copyWith(
      fontSize:
          kTitleExpandedSize +
          (kTitleCollapsedSize - kTitleExpandedSize) * progress,
    );

/// The top bar of a scrolling page: a BIG title that shrinks into a normal
/// app bar while the content scrolls up (and grows back at the top).
///
/// Used by every list / grid page except the photo viewer. It is one pinned
/// sliver, so the content scrolls under it and nothing else has to be laid
/// out again while it shrinks.
class CollapsingSliverAppBar extends StatelessWidget {
  const CollapsingSliverAppBar({
    required this.title,
    this.leading,
    this.actions = const [],
    this.backgroundColor,
    super.key,
  });

  final String title;

  /// For example a back button. The title then starts after it.
  final Widget? leading;
  final List<Widget> actions;

  /// null = the page's own background (most pages); a screen can set its
  /// own so the bar stands out (the private vault).
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _Delegate(
        title: title,
        leading: leading,
        actions: actions,
        topPadding: MediaQuery.paddingOf(context).top,
        backgroundColor:
            backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
      ),
    );
  }
}

class _Delegate extends SliverPersistentHeaderDelegate {
  _Delegate({
    required this.title,
    required this.leading,
    required this.actions,
    required this.topPadding,
    required this.backgroundColor,
  });

  final Color backgroundColor;

  /// How much taller the whole bar is when the title is big.
  static const double _extra = 32;

  final String title;
  final Widget? leading;
  final List<Widget> actions;
  final double topPadding;

  @override
  double get minExtent => topPadding + kToolbarHeight;

  @override
  double get maxExtent => topPadding + kToolbarHeight + _extra;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final t = math.min(1.0, math.max(0.0, shrinkOffset / _extra));
    final style = collapsingTitleStyle(context, t);
    final startX = leading == null ? 16.0 : 56.0;

    // Title and icons share ONE row, pinned to the bottom of the bar. The
    // whole bar gets shorter while scrolling, so the row moves up together
    // (icons keep their size, only the title text shrinks).
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value:
          Theme.of(context).appBarTheme.systemOverlayStyle ??
          (Theme.of(context).brightness == Brightness.dark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark),
      child: ColoredBox(
        color: backgroundColor,
        child: Stack(
          children: [
            Positioned(
              left: startX,
              right: 4 + actions.length * 48.0,
              bottom: 6,
              height: kToolbarHeight,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 4,
              bottom: 5,
              height: kToolbarHeight,
              child: Row(children: [?leading, const Spacer(), ...actions]),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_Delegate old) =>
      old.title != title ||
      old.backgroundColor != backgroundColor ||
      old.topPadding != topPadding ||
      old.leading != leading ||
      old.actions != actions;
}
