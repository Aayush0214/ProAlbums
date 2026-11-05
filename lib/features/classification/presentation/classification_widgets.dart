import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/classification/presentation/classification_providers.dart';
import 'package:proalbums/features/classification/presentation/place_providers.dart';
import 'package:proalbums/features/classification/presentation/thing_providers.dart';

/// Starts Intelligent classification's scan a few seconds after the app
/// opens (so the first screen loads first), in the background, so People
/// is ready by the time the user goes to Albums.
class ClassificationAutoStart extends ConsumerStatefulWidget {
  const ClassificationAutoStart({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ClassificationAutoStart> createState() =>
      _ClassificationAutoStartState();
}

class _ClassificationAutoStartState
    extends ConsumerState<ClassificationAutoStart> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      ref.read(faceScanProvider.notifier).ensureStarted();
      ref.read(placeScanProvider.notifier).ensureStarted();
      ref.read(thingScanProvider.notifier).ensureStarted();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Settings > "Intelligent classification".
class ClassificationSettingTile extends ConsumerWidget {
  const ClassificationSettingTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(
      classificationEnabledProvider.select((value) => value.value ?? true),
    );
    return SwitchListTile(
      title: const Text('Intelligent classification'),
      subtitle: Text(
        'Groups pictures by people, places and things, on this phone only.',
        style: context.textTheme.bodySmall?.copyWith(
          color: context.colors.textSecondary,
        ),
      ),
      value: enabled,
      onChanged: (on) =>
          ref.read(classificationEnabledProvider.notifier).save(enabled: on),
    );
  }
}
