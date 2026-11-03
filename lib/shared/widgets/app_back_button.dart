import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The app's back button: Flutter's BackButton, but with the Lucide chevron
/// used everywhere else (Settings has the same one).
class AppBackButton extends StatelessWidget {
  const AppBackButton({this.onPressed, super.key});

  /// null = go back (pop this screen).
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      icon: const Icon(LucideIcons.chevronLeft),
      onPressed: onPressed ?? () => Navigator.maybePop(context),
    );
  }
}
