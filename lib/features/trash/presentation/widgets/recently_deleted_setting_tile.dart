import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/trash/presentation/providers/recently_deleted_setting.dart';
import 'package:proalbums/features/trash/presentation/widgets/turn_off_recently_deleted.dart';

/// The "Recently deleted" switch for the Settings screen.
/// ON: deleted items wait 30 days in the trash. OFF: deleted for good.
class RecentlyDeletedSettingTile extends ConsumerWidget {
  const RecentlyDeletedSettingTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(
      recentlyDeletedEnabledProvider.select((value) => value.value ?? true),
    );
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: const Text('Recently deleted'),
      subtitle: Text(
        'Deleted images and videos will be displayed in "Recently deleted".',
        style: context.textTheme.bodySmall
            ?.copyWith(color: context.colors.textSecondary),
      ),
      value: enabled,
      onChanged: (on) async {
        final setting = ref.read(recentlyDeletedEnabledProvider.notifier);
        if (on) {
          await setting.save(enabled: true);
        } else {
          // Asks first, empties the trash, then saves. If the person cancels,
          // the switch simply stays on.
          await turnOffRecentlyDeleted(context, ref);
        }
      },
    );
  }
}
