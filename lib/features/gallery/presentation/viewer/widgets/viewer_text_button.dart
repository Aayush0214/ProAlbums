import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/classification/presentation/thing_providers.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';

/// The viewer's round [T] button (like the system gallery): shown only on a
/// picture the scan found text in; on = filled with the accent colour and
/// every line of text is highlighted on the picture.
class ViewerTextButton extends ConsumerWidget {
  const ViewerTextButton({
    required this.item,
    required this.on,
    required this.onTap,
    super.key,
  });

  final MediaItem item;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasText = ref.watch(photoHasTextProvider(item.id)).value ?? false;
    if (!hasText) return const SizedBox.shrink();
    final scheme = context.colorScheme;
    return Material(
      color: on ? scheme.primary : AppColors.mediaBadgeFill,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(
            LucideIcons.scanText,
            size: 24,
            color: on ? scheme.onPrimary : AppColors.mediaBadgeText,
          ),
        ),
      ),
    );
  }
}
