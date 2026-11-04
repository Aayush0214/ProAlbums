import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/vault/presentation/providers/vault_providers.dart';
import 'package:proalbums/features/vault/presentation/vault_flows.dart';

/// Settings rows of the private vault: "Hidden photos" (the only way in)
/// and the "Password for hidden photos" switch. Rows only; the settings
/// screen puts the dividers around them.
class HiddenPhotosSettingTile extends ConsumerWidget {
  const HiddenPhotosSettingTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: const Text('Hidden photos'),
      subtitle: const Text('Show hidden images and videos.'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Encrypted', style: context.textTheme.bodySmall),
          const SizedBox(width: 4),
          Icon(
            LucideIcons.chevronRight,
            size: 18,
            color: context.colors.textSecondary,
          ),
        ],
      ),
      onTap: () => openHiddenPhotos(context, ref),
    );
  }
}

class VaultPasswordSettingTile extends ConsumerWidget {
  const VaultPasswordSettingTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(
      vaultSessionProvider.select((status) => status.value?.passwordEnabled),
    );
    return SwitchListTile(
      title: const Text('Password for hidden photos'),
      subtitle: const Text('Privacy password is required for verification'),
      value: enabled ?? false,
      // Off until the state is known (never shows a wrong value).
      onChanged: enabled == null
          ? null
          : (value) => setVaultPassword(context, ref, enabled: value),
    );
  }
}
