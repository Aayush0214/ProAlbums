import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/app/router/app_routes.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/classification/domain/thing_rules.dart';
import 'package:proalbums/features/classification/presentation/classification_providers.dart';
import 'package:proalbums/features/classification/presentation/people_providers.dart';
import 'package:proalbums/features/classification/presentation/place_providers.dart';
import 'package:proalbums/features/classification/presentation/thing_providers.dart';
import 'package:proalbums/features/classification/presentation/widgets/face_avatar.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/widgets/media_thumbnail.dart';

/// Albums tab: "Intelligent classification  More >" and its tiles side by
/// side (People, Location, then the things). Hidden when
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
    final hasPlaces = ref.watch(
      placeAlbumListProvider.select((a) => a.value?.isNotEmpty ?? false),
    );
    final things = ref.watch(
      thingAlbumListProvider.select(
        (a) => [
          for (final kind in ThingKind.values)
            if (a.value?[kind]?.isNotEmpty ?? false) kind,
        ],
      ),
    );
    if (ready && !hasPeople && !hasPlaces && things.isEmpty) {
      return const SizedBox.shrink();
    }
    final tiles = <Widget>[
      if (hasPeople || !ready) const PeopleTile(),
      if (hasPlaces) const LocationTile(),
      for (final kind in things) ThingTile(kind: kind),
    ];

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
              children: [
                for (final (i, t) in tiles.indexed) ...[
                  if (i > 0) const SizedBox(width: _gap),
                  SizedBox(width: tile, child: t),
                ],
              ],
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

/// "Location" with the newest picture of the 4 biggest places in a 2×2,
/// and how many places there are.
class LocationTile extends ConsumerWidget {
  const LocationTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albums = ref.watch(placeAlbumListProvider).value ?? const [];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => unawaited(context.push<void>(AppRoutes.locations)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: LayoutBuilder(
              builder: (context, constraints) {
                const gap = 4.0;
                final square = (constraints.maxWidth - gap) / 2;
                Widget slot(int i) => SizedBox.square(
                  dimension: square,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: i < albums.length
                        ? MediaThumbnail(
                            item: MediaItem(
                              id: albums[i].pictures.first.id,
                              type: MediaType.image,
                              createdAt: DateTime.fromMillisecondsSinceEpoch(
                                albums[i].pictures.first.takenMs,
                              ),
                              width: 0,
                              height: 0,
                            ),
                            size: 192,
                          )
                        : ColoredBox(
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
          Text('Location', style: context.textTheme.bodyMedium),
          Text(
            NumberFormat.decimalPattern().format(albums.length),
            style: context.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// One thing (Documents, Food…): its newest picture, the name, the count.
class ThingTile extends ConsumerWidget {
  const ThingTile({required this.kind, super.key});

  final ThingKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pictures = ref.watch(thingAlbumListProvider).value?[kind] ?? const [];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => unawaited(context.push<void>(AppRoutes.thing(kind.name))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: pictures.isEmpty
                  ? ColoredBox(color: context.colorScheme.surfaceContainerHigh)
                  : MediaThumbnail(
                      item: MediaItem(
                        id: pictures.first.id,
                        type: MediaType.image,
                        createdAt: DateTime.fromMillisecondsSinceEpoch(
                          pictures.first.takenMs,
                        ),
                        width: 0,
                        height: 0,
                      ),
                      size: 320,
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            kind.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.bodyMedium,
          ),
          Text(
            NumberFormat.decimalPattern().format(pictures.length),
            style: context.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
