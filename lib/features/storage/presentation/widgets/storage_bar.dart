import 'package:flutter/material.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/storage/domain/entities/storage_usage.dart';
import 'package:proalbums/features/storage/presentation/widgets/storage_style.dart';

/// One rounded bar: a coloured piece per kind (width = its share of the whole
/// storage), thin gaps between them, and the free space as the empty track.
class StorageBar extends StatelessWidget {
  const StorageBar({required this.usage, this.height = 12, super.key});

  final StorageUsage usage;
  final double height;

  @override
  Widget build(BuildContext context) {
    final used = [
      for (final s in usage.segments)
        if (s.bytes > 0) s,
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: ColoredBox(
          color: context.colorScheme.surfaceContainerHighest,
          child: Row(
            // Without this the pieces have NO height inside a Row and the bar
            // looks empty.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < used.length; i++) ...[
                if (i > 0) const SizedBox(width: 3),
                Expanded(
                  // A small kind is still clearly visible: never thinner than
                  // 1.5% of the bar (a little wider than its real share).
                  flex: (used[i].bytes / usage.total * 1000)
                      .round()
                      .clamp(15, 1000),
                  child: ColoredBox(
                    color: storageColorOf(used[i].kind, context),
                  ),
                ),
              ],
              Expanded(
                flex: (usage.free / usage.total * 1000).round().clamp(1, 1000),
                child: const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
