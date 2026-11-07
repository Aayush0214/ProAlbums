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
import 'package:proalbums/features/search/presentation/search_providers.dart';

/// Opens a Search result page.
void openSearchResult(BuildContext context, SearchTarget target) =>
    unawaited(context.push<void>(AppRoutes.searchResult, extra: target));

/// The Search tab before typing: Recent searches, then People, Location
/// and Types (side-scrolling, each with "More >"). A person opens a plain
/// grid here (not the slideshow page of the Albums tab).
class SearchHome extends ConsumerWidget {
  const SearchHome({required this.onRecent, super.key});

  /// A recent search was tapped (search it again).
  final ValueChanged<String> onRecent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(
      classificationEnabledProvider.select((value) => value.value ?? true),
    );
    return SliverMainAxisGroup(
      slivers: [
        SearchRecent(onRecent: onRecent),
        if (enabled) ...const [
          SliverToBoxAdapter(child: _PeopleRow()),
          SliverToBoxAdapter(child: _LocationRow()),
          SliverToBoxAdapter(child: _TypesRow()),
        ],
        // The bottom bar floats over the body (see MainShellPage): its height
        // is in the bottom padding, so the last row is not hidden behind it.
        SliverToBoxAdapter(
          child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 16),
        ),
      ],
    );
  }
}

/// "Recent searches 🗑" and the searches as small chips, 4 per line, at
/// most 2 lines (nothing when empty). A long press shows ✕ on every chip
/// (remove one by one); a tap outside the section (or on a chip) ends it.
class SearchRecent extends ConsumerStatefulWidget {
  const SearchRecent({required this.onRecent, super.key});

  final ValueChanged<String> onRecent;

  @override
  ConsumerState<SearchRecent> createState() => _SearchRecentState();
}

class _SearchRecentState extends ConsumerState<SearchRecent> {
  static const int _perRow = 4;

  /// The ✕ on every chip are shown.
  bool _removing = false;

  @override
  Widget build(BuildContext context) {
    final recent = ref.watch(recentSearchesProvider).value ?? const [];
    if (recent.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final notifier = ref.read(recentSearchesProvider.notifier);

    Widget chip(String text) => _RecentChip(
      text: text,
      removing: _removing,
      onTap: () =>
          _removing ? setState(() => _removing = false) : widget.onRecent(text),
      onLongPress: () => setState(() => _removing = true),
      onRemove: () {
        if (recent.length == 1) setState(() => _removing = false);
        unawaited(notifier.remove(text));
      },
    );

    return SliverToBoxAdapter(
      // While the ✕ are shown, a tap anywhere outside this section ends it
      // (like the system gallery): the page, the search bar (opening the
      // search page) or the bottom bar (another tab).
      child: TapRegion(
        onTapOutside: _removing
            ? (_) => setState(() => _removing = false)
            : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Recent searches',
                      style: context.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Clear recent searches',
                    icon: const Icon(LucideIcons.trash2, size: 20),
                    onPressed: () {
                      setState(() => _removing = false);
                      unawaited(notifier.clear());
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  children: [
                    for (var row = 0; row * _perRow < recent.length; row++)
                      Padding(
                        padding: EdgeInsets.only(top: row == 0 ? 0 : 2),
                        child: Row(
                          children: [
                            for (var col = 0; col < _perRow; col++) ...[
                              if (col > 0) const SizedBox(width: 8),
                              Expanded(
                                child: row * _perRow + col < recent.length
                                    ? chip(recent[row * _perRow + col])
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One recent search: a small pill, the text cut with … when long; while
/// removing, a small ✕ at its top-right corner.
class _RecentChip extends StatelessWidget {
  const _RecentChip({
    required this.text,
    required this.removing,
    required this.onTap,
    required this.onLongPress,
    required this.onRemove,
  });

  final String text;
  final bool removing;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    // The ✕ sits in this widget's own top-right corner (a touch outside
    // a widget's box is not delivered to it), so the pill leaves room.
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10, right: 8),
          child: Material(
            color: scheme.surfaceContainerHigh,
            shape: const StadiumBorder(),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: onTap,
              onLongPress: onLongPress,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Center(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: scheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (removing)
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onRemove,
              // A bigger touch area than the small dot.
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.onSurfaceVariant,
                  ),
                  child: Icon(LucideIcons.x, size: 12, color: scheme.surface),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A section title with "More >".
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.onMore});

  final String title;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 4, 4),
    child: Row(
      children: [
        Expanded(child: Text(title, style: context.textTheme.titleLarge)),
        TextButton(
          onPressed: onMore,
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
  );
}

/// Width of one side-scrolling tile (a bit more than 4 fit, so the row
/// looks scrollable).
double _tileSide(BuildContext context) =>
    (MediaQuery.sizeOf(context).width - 16 - 12 * 4) / 4.3;

/// People on the People page as circles, the name under named ones.
class _PeopleRow extends ConsumerWidget {
  const _PeopleRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = ref.watch(peopleShownProvider);
    if (people.isEmpty) return const SizedBox.shrink();
    final side = _tileSide(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          title: 'People',
          onMore: () => unawaited(context.push<void>(AppRoutes.searchPeople)),
        ),
        SizedBox(
          height: side + 28,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: people.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final person = people[i];
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => openSearchResult(
                  context,
                  SearchTarget(
                    kind: SearchTargetKind.person,
                    key: '${person.id}',
                    title: person.name ?? '',
                  ),
                ),
                child: SizedBox(
                  width: side,
                  child: Column(
                    children: [
                      FaceAvatar(face: person.cover, diameter: side),
                      const SizedBox(height: 4),
                      if (person.name case final name?)
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.bodyMedium,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A square picture with a name and a count under it.
class _AlbumTile extends StatelessWidget {
  const _AlbumTile({
    required this.cover,
    required this.title,
    required this.count,
    required this.onTap,
  });

  final MediaItem? cover;
  final String title;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final side = _tileSide(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: side,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox.square(
              dimension: side,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: switch (cover) {
                  final item? => MediaThumbnail(item: item, size: 320),
                  null => ColoredBox(
                    color: context.colorScheme.surfaceContainerHigh,
                  ),
                },
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodyMedium,
            ),
            Text(
              NumberFormat.decimalPattern().format(count),
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

MediaItem _picture(String id, int takenMs) => MediaItem(
  id: id,
  type: MediaType.image,
  createdAt: DateTime.fromMillisecondsSinceEpoch(takenMs),
  width: 0,
  height: 0,
);

class _TilesRow extends StatelessWidget {
  const _TilesRow({required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) => SizedBox(
    // Picture + 2 lines of name + the count.
    height: _tileSide(context) + 60,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: tiles.length,
      separatorBuilder: (_, _) => const SizedBox(width: 12),
      itemBuilder: (context, i) => tiles[i],
    ),
  );
}

/// The place albums (most pictures first).
class _LocationRow extends ConsumerWidget {
  const _LocationRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final places = ref.watch(placeAlbumListProvider).value ?? const [];
    if (places.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          title: 'Location',
          onMore: () => unawaited(context.push<void>(AppRoutes.locations)),
        ),
        _TilesRow(
          tiles: [
            for (final place in places)
              _AlbumTile(
                cover: place.pictures.isEmpty
                    ? null
                    : _picture(
                        place.pictures.first.id,
                        place.pictures.first.takenMs,
                      ),
                title: place.name,
                count: place.pictures.length,
                onTap: () => openSearchResult(
                  context,
                  SearchTarget(
                    kind: SearchTargetKind.place,
                    key: place.name,
                    title: place.name,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// The things (Documents, Group photo…), in the system gallery's order.
class _TypesRow extends ConsumerWidget {
  const _TypesRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albums = ref.watch(thingAlbumListProvider).value ?? const {};
    final kinds = [
      for (final kind in ThingKind.values)
        if (albums[kind]?.isNotEmpty ?? false) kind,
    ];
    if (kinds.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          title: 'Types',
          onMore: () => unawaited(context.push<void>(AppRoutes.classification)),
        ),
        _TilesRow(
          tiles: [
            for (final kind in kinds)
              _AlbumTile(
                cover: _picture(
                  albums[kind]!.first.id,
                  albums[kind]!.first.takenMs,
                ),
                title: kind.title,
                count: albums[kind]!.length,
                onTap: () => openSearchResult(
                  context,
                  SearchTarget(
                    kind: SearchTargetKind.thing,
                    key: kind.name,
                    title: kind.title,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
