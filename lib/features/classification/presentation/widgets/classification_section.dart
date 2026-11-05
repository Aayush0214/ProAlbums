import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/app/router/app_routes.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/classification/presentation/classification_providers.dart';
import 'package:proalbums/features/classification/presentation/people_providers.dart';
import 'package:proalbums/features/classification/presentation/widgets/face_avatar.dart';

/// Albums tab: "Intelligent classification  More >" and its tiles side by
/// side (People for now; Location and the things come later). Hidden when
/// Settings > Intelligent classification is off, or when nothing was found.
class ClassificationSection extends ConsumerWidget {
  const ClassificationSection({super.key});

  static const double _side = 16;
  static const double _gap = 12;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(
      classificationEnabledProvider.select((value) => value.value ?? true),
    );
    if (!enabled) return const SizedBox.shrink();
    final ready = ref.watch(faceScanProvider.select((s) => s.ready));
    final hasPeople = ref.watch(
      peopleShownProvider.select((people) => people.isNotEmpty),
    );
    if (ready && !hasPeople) return const SizedBox.shrink();

    // Same tile size as the albums above (3 per row).
    final width = MediaQuery.sizeOf(context).width;
    final tile = (width - _side * 2 - _gap * 2) / 3;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(_side, 8, 4, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Intelligent classification',
                    style: context.textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      unawaited(context.push<void>(AppRoutes.classification)),
                  style: TextButton.styleFrom(
                    foregroundColor: context.colors.textSecondary,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('More'),
                      SizedBox(width: 2),
                      Icon(LucideIcons.chevronRight, size: 18),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: tile + 6 + 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: _side),
              children: [SizedBox(width: tile, child: const PeopleTile())],
            ),
          ),
        ],
      ),
    );
  }
}

/// "People" with the first 4 faces in a 2×2 of circles, and how many
/// people are on the People page ("Scanning…" until the first scan ends).
class PeopleTile extends ConsumerWidget {
  const PeopleTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = ref.watch(peopleShownProvider);
    final ready = ref.watch(faceScanProvider.select((s) => s.ready));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => unawaited(context.push<void>(AppRoutes.people)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: LayoutBuilder(
              builder: (context, constraints) {
                const gap = 4.0;
                final circle = (constraints.maxWidth - gap) / 2;
                Widget slot(int i) => i < people.length
                    ? FaceAvatar(face: people[i].cover, diameter: circle)
                    : SizedBox.square(
                        dimension: circle,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: context.colorScheme.surfaceContainerHigh,
                          ),
                        ),
                      );
                return Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [slot(0), slot(1)],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [slot(2), slot(3)],
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Text('People', style: context.textTheme.bodyMedium),
          Text(
            !ready && people.isEmpty
                ? 'Scanning…'
                : NumberFormat.decimalPattern().format(people.length),
            style: context.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
