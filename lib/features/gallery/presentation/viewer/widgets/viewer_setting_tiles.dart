import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/gallery/presentation/viewer/providers/viewer_settings.dart';

TextStyle? _subtitleStyle(BuildContext context) =>
    context.textTheme.bodySmall?.copyWith(color: context.colors.textSecondary);

/// Settings > "Autoplay Videos".
class ViewerAutoplayTile extends ConsumerWidget {
  const ViewerAutoplayTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(
      viewerAutoplayProvider.select((value) => value.value ?? false),
    );
    return SwitchListTile(
      title: const Text('Autoplay Videos'),
      subtitle: Text(
        'Videos are muted by default when autoplaying.',
        style: _subtitleStyle(context),
      ),
      value: on,
      onChanged: (value) =>
          ref.read(viewerAutoplayProvider.notifier).save(on: value),
    );
  }
}

/// Settings > "Keep screen on while viewing".
class ViewerKeepScreenOnTile extends ConsumerWidget {
  const ViewerKeepScreenOnTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(
      viewerKeepScreenOnProvider.select((value) => value.value ?? false),
    );
    return SwitchListTile(
      title: const Text('Keep screen on while viewing'),
      subtitle: Text(
        'The screen does not turn off while a photo is open.',
        style: _subtitleStyle(context),
      ),
      value: on,
      onChanged: (value) =>
          ref.read(viewerKeepScreenOnProvider.notifier).save(on: value),
    );
  }
}

/// Settings > "Auto-rotate when viewing photos": Always / Never.
class ViewerAutoRotateTile extends ConsumerWidget {
  const ViewerAutoRotateTile({super.key});

  Future<void> _choose(BuildContext context, WidgetRef ref) async {
    final current =
        ref.read(viewerAutoRotateProvider).value ?? ViewerRotation.always;
    final chosen = await showDialog<ViewerRotation>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                child: Text(
                  'Auto-rotate when viewing photos',
                  style: context.textTheme.titleLarge,
                ),
              ),
              for (final rotation in ViewerRotation.values)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  title: Text(rotation.label),
                  trailing: rotation == current
                      ? Icon(
                          LucideIcons.check,
                          color: context.colorScheme.primary,
                        )
                      : null,
                  onTap: () => Navigator.of(context).pop(rotation),
                ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null) {
      await ref.read(viewerAutoRotateProvider.notifier).save(chosen);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rotation = ref.watch(
      viewerAutoRotateProvider.select(
        (value) => value.value ?? ViewerRotation.always,
      ),
    );
    return ListTile(
      title: const Text('Auto-rotate when viewing photos'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(rotation.label, style: _subtitleStyle(context)),
          const SizedBox(width: 4),
          Icon(
            LucideIcons.chevronRight,
            size: 18,
            color: context.colors.textSecondary,
          ),
        ],
      ),
      onTap: () => unawaited(_choose(context, ref)),
    );
  }
}
