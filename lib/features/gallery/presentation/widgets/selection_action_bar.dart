import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/features/gallery/presentation/providers/photos_selection_controller.dart';
import 'package:proalbums/features/gallery/presentation/providers/share_providers.dart';

/// Bottom bar while selecting. Only "Share" for now; Delete, Favorite, Add to
/// album and Hide arrive with their own phases.
class SelectionActionBar extends ConsumerWidget {
  const SelectionActionBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(
      photosSelectionControllerProvider.select((s) => s.count),
    );
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surface,
      elevation: 3,
      // Needed because this bar REPLACES the navigation bar (see PhotosPage),
      // so it must keep clear of the phone's gesture area by itself.
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _BarAction(
                icon: LucideIcons.share2,
                label: 'Share',
                onPressed: count == 0 ? null : () => _share(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _share(BuildContext context, WidgetRef ref) async {
    final ids = ref.read(photosSelectionControllerProvider).ids.toList();
    final messenger = ScaffoldMessenger.of(context);

    final result = await ref.read(shareMediaUseCaseProvider)(ids);

    result.match(
      (failure) => messenger.showSnackBar(
        const SnackBar(content: Text('Could not share the selected items.')),
      ),
      (_) {},
    );
  }
}

class _BarAction extends StatelessWidget {
  const _BarAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final color = enabled
        ? Theme.of(context).colorScheme.onSurface
        : Theme.of(context).disabledColor;

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
