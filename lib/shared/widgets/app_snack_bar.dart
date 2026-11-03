import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Widest a message may be. On a phone held upright the message spans the
/// screen (minus the side gap); in landscape it stays this wide, centred.
const double kSnackBarMaxWidth = 480;

/// Shows a floating message that
/// - never gets wider than [kSnackBarMaxWidth] (landscape / tablets),
/// - can sit [bottomInset] above the screen's bottom edge, so it does not
///   cover a bottom bar (the viewer passes its bar heights).
///
/// Colours and shape come from the app theme (snackBarTheme).
void showAppSnackBar(
  BuildContext context,
  String text, {
  double bottomInset = 0,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  showAppSnackBarOn(
    ScaffoldMessenger.of(context),
    MediaQuery.sizeOf(context).width,
    text,
    bottomInset: bottomInset,
    actionLabel: actionLabel,
    onAction: onAction,
  );
}

/// Same, for code that already took the messenger and the screen width
/// BEFORE an `await` (the screen may be gone by the time the message shows).
void showAppSnackBarOn(
  ScaffoldMessengerState messenger,
  double screenWidth,
  String text, {
  double bottomInset = 0,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  // Side gap: 16, or more on wide screens so the message stays centred and
  // not wider than kSnackBarMaxWidth. A margin (not `width`) is used because
  // it also lets the message sit above a bottom bar.
  final side = math.max(16.0, (screenWidth - kSnackBarMaxWidth) / 2);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        // A SnackBar with an action STAYS on screen until dismissed unless
        // `persist` is false. We want it to go away by itself.
        persist: false,
        duration: Duration(seconds: actionLabel == null ? 3 : 5),
        margin: EdgeInsets.fromLTRB(
          side,
          0,
          side,
          bottomInset > 0 ? bottomInset + 8 : 16,
        ),
        content: Text(text),
        // A button on the message ("Undo"). Colours come from the theme.
        action: actionLabel == null || onAction == null
            ? null
            : SnackBarAction(label: actionLabel, onPressed: onAction),
      ),
    );
}

/// For buttons whose phase is not built yet.
void showComingSoon(BuildContext context, String what) {
  showAppSnackBar(context, '$what is coming in a later update.');
}
