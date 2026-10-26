import 'package:flutter/material.dart';
import 'package:proalbums/core/theme/app_colors.dart';

/// Temporary body for tabs whose real page is built in a later phase.
/// Deleted page by page as the roadmap moves forward.
class PhasePlaceholder extends StatelessWidget {
  const PhasePlaceholder({
    required this.title,
    required this.message,
    super.key,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: context.textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }
}
