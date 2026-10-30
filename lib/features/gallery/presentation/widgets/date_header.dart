import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/core/utils/date_label.dart';
import 'package:proalbums/features/gallery/domain/entities/media_group.dart';
import 'package:proalbums/features/gallery/presentation/providers/photos_selection_controller.dart';
import 'package:proalbums/features/gallery/presentation/widgets/selection_checkbox.dart';

/// "October 12  Monday" (or "October 2026" in the month overview).
/// Used both inside the list and as the sticky overlay.
///
/// While selecting, a checkbox appears in front: it selects (or unselects) ALL
/// photos of that day at once.
class DateHeader extends ConsumerWidget {
  const DateHeader({
    required this.day,
    this.itemIds = const <String>[],
    this.granularity = GroupGranularity.day,
    super.key,
  });

  final DateTime day;

  /// Ids of the photos under this header (for the checkbox).
  final List<String> itemIds;
  final GroupGranularity granularity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // null = not selecting -> no checkbox.
    final selection = ref.watch(
      photosSelectionControllerProvider
          .select((s) => s.active ? s.stateOf(itemIds) : null),
    );

    final label = granularity == GroupGranularity.month
        ? (title: formatMonthLabel(day), subtitle: '')
        : formatDayLabel(day, now: DateTime.now());

    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            if (selection != null) ...[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => ref
                    .read(photosSelectionControllerProvider.notifier)
                    .toggleGroup(itemIds),
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: SelectionCheckbox(state: selection),
                ),
              ),
            ],
            Text(label.title, style: context.textTheme.headlineSmall),
            if (label.subtitle.isNotEmpty) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodySmall,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
