import 'package:flutter/widgets.dart';
import 'package:proalbums/shared/widgets/app_toast.dart';

export 'package:proalbums/shared/widgets/app_toast.dart';

/// Shows a short message as the app's toast (see [AppToast]): app icon +
/// text, above the bottom bar, 2 seconds (3.5 with an action).
///
/// [bottomInset]: what covers the bottom of the screen here (the viewer
/// passes its bar heights); 0 = the normal place above a bottom bar.
/// After an await, take `AppToast.of(context)` BEFORE it and call `show`.
void showAppSnackBar(
  BuildContext context,
  String text, {
  double bottomInset = 0,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  AppToast.of(context).show(
    text,
    bottomInset: bottomInset,
    actionLabel: actionLabel,
    onAction: onAction,
  );
}

/// For buttons whose phase is not built yet.
void showComingSoon(BuildContext context, String what) {
  showAppSnackBar(context, '$what is coming in a later update.');
}
