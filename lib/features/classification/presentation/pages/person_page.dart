import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/albums/presentation/widgets/album_selection_widgets.dart';
import 'package:proalbums/features/classification/data/face_repository.dart';
import 'package:proalbums/features/classification/domain/face_rules.dart';
import 'package:proalbums/features/classification/presentation/people_flows.dart';
import 'package:proalbums/features/classification/presentation/people_providers.dart';
import 'package:proalbums/features/classification/presentation/widgets/face_avatar.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/actions/media_actions.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_grid.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_grid_skeleton.dart';
import 'package:proalbums/features/gallery/presentation/images/media_thumbnail_image.dart';
import 'package:proalbums/features/gallery/presentation/providers/media_selection.dart';
import 'package:proalbums/features/gallery/presentation/viewer/providers/viewer_providers.dart';
import 'package:proalbums/features/gallery/presentation/viewer/viewer_math.dart';
import 'package:proalbums/features/gallery/presentation/widgets/selection_action_bar.dart';
import 'package:proalbums/shared/widgets/slideshow_player.dart';

/// One person (like the system gallery): their featured pictures play as a
/// slideshow on top, under a see-through bar (back, select); "Add name"
/// bottom-left of it; "Similar people have been detected. Merge now";
/// then the featured pictures in 2 big columns, or every picture in 4 with
/// "Show all" ("Show featured photos" goes back). The pictures are on the
/// SHARED grid and viewer, with the person's actions (Set as cover, Not
/// this person). (The ▶ memory video comes with the For You page.)
class PersonPage extends ConsumerStatefulWidget {
  const PersonPage({required this.personId, this.onPlayMemory, super.key});

  final int personId;

  /// ▶ on the slideshow: plays this person's memory (For You). Given by the
  /// app (classification does not know memories); null = no ▶.
  final void Function(
    BuildContext context,
    WidgetRef ref,
    PersonSummary person,
  )?
  onPlayMemory;

  @override
  ConsumerState<PersonPage> createState() => _PersonPageState();
}

class _PersonPageState extends ConsumerState<PersonPage> {
  final ScrollController _scroll = ScrollController();
  bool _showAll = false;
  bool _leaving = false;

  String get _scopeId => personAlbumId(widget.personId);

  MediaSelectionControllerProvider get _selectionProvider =>
      mediaSelectionControllerProvider(_scopeId);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// The person is gone (merged into someone else, every picture removed).
  void _leave() {
    if (_leaving) return;
    _leaving = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && context.canPop()) context.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.personId;
    final loaded = ref.watch(allPeopleProvider).hasValue;
    final person = ref.watch(personProvider(id));
    if (person == null) {
      if (loaded) _leave();
      return const Scaffold();
    }
    final facesLoading = ref.watch(personFacesProvider(id)).isLoading;
    final all = ref.watch(personItemsProvider(id));
    final featured = ref.watch(personFeaturedProvider(id));
    final shown = _showAll ? all : featured;
    final shownProvider = _showAll
        ? personItemsProvider(id)
        : personFeaturedProvider(id);
    final columns = personGridColumns(showAll: _showAll);
    final selecting = ref.watch(_selectionProvider.select((s) => s.active));
    final selection = ref.read(_selectionProvider.notifier);
    final top = MediaQuery.paddingOf(context).top;

    final leading = <Widget>[
      if (selecting)
        Consumer(
          builder: (context, ref, _) {
            final count = ref.watch(_selectionProvider.select((s) => s.count));
            return AlbumSelectionHeader(
              selectedCount: count,
              itemCount: shown.length,
              onSelectAllToggle: () => count == shown.length
                  ? selection.clearSelection()
                  : selection.selectAll([for (final i in shown) i.id]),
              onClose: selection.exit,
            );
          },
        )
      else ...[
        SliverPersistentHeader(
          pinned: true,
          delegate: _PersonHeader(
            person: person,
            featured: featured,
            topPadding: top,
            height: MediaQuery.sizeOf(context).height * 0.42,
            onSelect: shown.isEmpty ? null : selection.start,
            onAddName: () => addPersonName(context, ref, person),
            onPlay: switch (widget.onPlayMemory) {
              final play? => () => play(context, ref, person),
              null => null,
            },
          ),
        ),
        _SimilarBanner(person: person),
      ],
      SliverToBoxAdapter(
        child: SizedBox(
          height: 52,
          child: all.length > featured.length
              ? Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: context.colors.textSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    onPressed: () {
                      selection.exitIfOpen();
                      setState(() => _showAll = !_showAll);
                    },
                    child: Text(_showAll ? 'Show featured photos' : 'Show all'),
                  ),
                )
              : null,
        ),
      ),
    ];

    return MediaScope(
      id: _scopeId,
      mediaContext: MediaContext.person,
      items: personItemsProvider(id),
      albumId: _scopeId,
      child: PopScope(
        // Back while selecting = leave select mode, not the page.
        canPop: !selecting,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) selection.exit();
        },
        child: Scaffold(
          bottomNavigationBar: selecting ? const SelectionActionBar() : null,
          body: facesLoading && shown.isEmpty
              ? CustomScrollView(
                  slivers: [
                    ...leading,
                    SliverGalleryGridSkeleton(columns: columns),
                  ],
                )
              : GalleryGrid(
                  // 2 ↔ 4 columns: the grid keeps the picture at the top in
                  // place (like a zoom).
                  controller: _scroll,
                  rows: ref.watch(personRowsProvider(id, showAll: _showAll)),
                  items: shown,
                  columns: columns,
                  reversed: false,
                  viewerItems: shownProvider,
                  thumbTopInset: top + kToolbarHeight + 8,
                  leadingSlivers: leading,
                  // Fixed columns, no pinch (like the system gallery).
                  onZoomIn: () {},
                  onZoomOut: () {},
                ),
        ),
      ),
    );
  }
}

/// The slideshow of the featured pictures with the see-through bar on it;
/// scrolled up it becomes a normal bar with the name.
class _PersonHeader extends SliverPersistentHeaderDelegate {
  _PersonHeader({
    required this.person,
    required this.featured,
    required this.topPadding,
    required this.height,
    required this.onSelect,
    required this.onAddName,
    this.onPlay,
  });

  final PersonSummary person;
  final List<MediaItem> featured;
  final double topPadding;
  final double height;
  final VoidCallback? onSelect;
  final VoidCallback onAddName;

  /// ▶ (the person's memory); null = not shown.
  final VoidCallback? onPlay;

  @override
  double get minExtent => topPadding + kToolbarHeight;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final t = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final iconColor = Color.lerp(
      AppColors.mediaBadgeText,
      context.colorScheme.onSurface,
      t,
    );
    final background = Theme.of(context).scaffoldBackgroundColor;

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: background),
        Opacity(
          opacity: 1 - t,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _HeaderSlideshow(featured: featured),
              // Keeps the bar's icons readable on any picture.
              const Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.mediaScrimTop, Color(0x00000000)],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 20,
                bottom: 20,
                child: _NameChip(name: person.name, onTap: onAddName),
              ),
              if (onPlay case final play?)
                Positioned(
                  right: 16,
                  bottom: 14,
                  child: Material(
                    color: AppColors.mediaBadgeFill,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: play,
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(
                          LucideIcons.play,
                          size: 24,
                          color: AppColors.mediaBadgeText,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: topPadding,
          height: kToolbarHeight,
          child: IconTheme(
            data: IconThemeData(color: iconColor),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Back',
                  icon: const Icon(LucideIcons.chevronLeft),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: Opacity(
                    opacity: t,
                    child: Text(
                      person.name ?? 'People',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.titleLarge,
                    ),
                  ),
                ),
                if (onSelect != null)
                  IconButton(
                    tooltip: 'Select',
                    icon: const Icon(LucideIcons.squareCheck),
                    onPressed: onSelect,
                  ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(_PersonHeader old) =>
      old.person != person ||
      old.featured != featured ||
      old.topPadding != topPadding ||
      old.height != height ||
      old.onSelect != onSelect ||
      (old.onPlay == null) != (onPlay == null);
}

/// The featured pictures, one after another for ever (the shared slideshow
/// engine, filling the banner).
class _HeaderSlideshow extends ConsumerWidget {
  const _HeaderSlideshow({required this.featured});

  final List<MediaItem> featured;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (featured.isEmpty) {
      return ColoredBox(color: context.colorScheme.surfaceContainerHigh);
    }
    final media = MediaQuery.of(context);
    final size = viewerImageLongEdge(
      media.size.longestSide * media.devicePixelRatio,
    );
    Future<Uint8List?> load(String id, int size) async {
      final result = await ref.read(loadDisplayImageUseCaseProvider)(
        id: id,
        maxLongEdge: size,
      );
      return result.fold((failure) => null, (bytes) => bytes);
    }

    final n = featured.length;
    return ClipRect(
      child: SlideshowPlayer(
        // A new show when the pictures change.
        key: ValueKey(featured.map((i) => i.id).join(',')),
        // "For ever": the list again and again.
        count: n == 1 ? 1 : n * 1000,
        imageAt: (index) => MediaThumbnailImage(
          id: featured[index % n].id,
          size: size,
          load: load,
        ),
        options: const SlideshowOptions(fit: BoxFit.cover, zoomTo: 1.15),
        onFinished: () {},
      ),
    );
  }
}

/// "Add name" (or the name) on the slideshow.
class _NameChip extends StatelessWidget {
  const _NameChip({required this.name, required this.onTap});

  final String? name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.mediaBadgeFill,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: Text(
              name ?? 'Add name',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.titleMedium?.copyWith(
                color: AppColors.mediaBadgeText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Similar people have been detected. Merge now ✕".
class _SimilarBanner extends ConsumerWidget {
  const _SimilarBanner({required this.person});

  final PersonSummary person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final similar = ref.watch(similarPersonProvider(person.id)).value;
    if (similar == null) return const SliverToBoxAdapter();
    return SliverToBoxAdapter(
      child: Material(
        color: context.colorScheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Row(
            children: [
              FaceAvatar(face: similar.cover, diameter: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Similar people have been detected.',
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    GestureDetector(
                      onTap: () => mergePeople(context, ref, [
                        similar,
                        person,
                      ], into: person),
                      child: Text(
                        'Merge now',
                        style: context.textTheme.bodyLarge?.copyWith(
                          color: context.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                icon: Icon(
                  LucideIcons.x,
                  size: 20,
                  color: context.colors.textSecondary,
                ),
                onPressed: () => ref
                    .read(dismissedSimilarProvider.notifier)
                    .dismiss(person.id, similar.id),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
