import 'package:flutter/material.dart';
import 'package:proalbums/core/theme/app_colors.dart';

/// [title] ("Compressing", "Transcoding"), the bar, "52%", Cancel — on a
/// card like the app's dialogs, at the bottom of the screen (like the system
/// gallery).
class CompressProgressCard extends StatelessWidget {
  const CompressProgressCard({
    required this.title,
    required this.percent,
    required this.onCancel,
    super.key,
  });

  final String title;
  final int percent;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Material(
        color: context.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: context.textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percent / 100,
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 8),
              Text('$percent%', style: context.textTheme.titleMedium),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: onCancel,
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
