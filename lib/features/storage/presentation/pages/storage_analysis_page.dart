import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/storage/domain/entities/storage_usage.dart';
import 'package:proalbums/features/storage/domain/services/format_bytes.dart';
import 'package:proalbums/features/storage/presentation/providers/storage_providers.dart';
import 'package:proalbums/features/storage/presentation/widgets/storage_donut.dart';
import 'package:proalbums/features/storage/presentation/widgets/storage_style.dart';
import 'package:proalbums/shared/widgets/collapsing_sliver_app_bar.dart';

/// "Storage analysis": the ring on top, then a card (2 columns) for each kind
/// with its size and its share of the storage.
class StorageAnalysisPage extends ConsumerWidget {
  const StorageAnalysisPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = ref.watch(storageUsageProvider).value;
    final width = MediaQuery.sizeOf(context).width;
    final ring = math.min(width * 0.62, 260.0);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const CollapsingSliverAppBar(
            title: 'Storage analysis',
            leading: BackButton(),
          ),
          if (usage == null || usage.total <= 0)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 28),
                child: Center(child: StorageDonut(usage: usage, size: ring)),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 112,
                ),
                itemCount: _kinds.length,
                itemBuilder: (context, index) => _KindCard(
                  kind: _kinds[index],
                  bytes: _bytesOf(usage, _kinds[index]),
                  share: usage.total == 0
                      ? 0
                      : _bytesOf(usage, _kinds[index]) / usage.total,
                ),
              ),
            ),
          ],
          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 24),
          ),
        ],
      ),
    );
  }

  static const _kinds = [
    StorageKind.photos,
    StorageKind.videos,
    StorageKind.screenshots,
    StorageKind.trash,
    StorageKind.other,
    StorageKind.free,
  ];

  static int _bytesOf(StorageUsage u, StorageKind kind) => switch (kind) {
        StorageKind.photos => u.photos,
        StorageKind.videos => u.videos,
        StorageKind.screenshots => u.screenshots,
        StorageKind.trash => u.trash,
        StorageKind.other => u.other,
        StorageKind.free => u.free,
      };
}

class _KindCard extends StatelessWidget {
  const _KindCard({
    required this.kind,
    required this.bytes,
    required this.share,
  });

  final StorageKind kind;
  final int bytes;

  /// 0..1 of the whole storage.
  final double share;

  @override
  Widget build(BuildContext context) {
    final color = storageColorOf(kind, context);
    return DecoratedBox(
      decoration: BoxDecoration(
        // Tinted with the kind's own colour, so each card matches its arc.
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  child: Padding(
                    padding: const EdgeInsets.all(7),
                    child: Icon(storageIconOf(kind), size: 16, color: Colors.white),
                  ),
                ),
                const Spacer(),
                Text(
                  formatPercent(share),
                  style: context.textTheme.labelMedium
                      ?.copyWith(color: context.colors.textSecondary),
                ),
              ],
            ),
            const Spacer(),
            Text(
              storageLabelOf(kind),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodyMedium
                  ?.copyWith(color: context.colors.textSecondary),
            ),
            const SizedBox(height: 2),
            Text(
              formatBytes(bytes),
              style: context.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}
