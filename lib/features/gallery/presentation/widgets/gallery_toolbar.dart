import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/core/theme/app_typography.dart';
import 'package:proalbums/features/gallery/domain/entities/media_page_request.dart';
import 'package:proalbums/features/gallery/presentation/providers/photos_controller.dart';
import 'package:proalbums/features/gallery/presentation/providers/photos_query_controller.dart';

/// First row of the list: "Library 2,660 items" and the All/Photos/Videos chips.
class GalleryToolbar extends ConsumerWidget {
  const GalleryToolbar({super.key});

  static const List<(MediaKind, String)> _filters = [
    (MediaKind.all, 'All'),
    (MediaKind.images, 'Photos'),
    (MediaKind.videos, 'Videos'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // select(): rebuild only when THIS value changes.
    final kind = ref.watch(photosQueryControllerProvider.select((q) => q.kind));
    final total = ref.watch(
      photosControllerProvider.select((value) => value.value?.totalCount),
    );
    final query = ref.read(photosQueryControllerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('Library', style: context.textTheme.headlineMedium),
              const SizedBox(width: 8),
              Text(
                total == null
                    ? ''
                    : '${NumberFormat.decimalPattern().format(total)} items',
                style: AppTypography.labelMono(color: context.colors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (filterKind, label) in _filters) ...[
                  ChoiceChip(
                    label: Text(label),
                    selected: kind == filterKind,
                    showCheckmark: false,
                    onSelected: (_) => query.setKind(filterKind),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
