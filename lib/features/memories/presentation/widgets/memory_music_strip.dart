import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/gallery/presentation/widgets/media_thumbnail.dart';
import 'package:proalbums/features/memories/data/memory_repository.dart';
import 'package:proalbums/features/memories/domain/memory_music.dart';
import 'package:proalbums/features/memories/presentation/widgets/memory_cards.dart';

/// The memory editor's music (the player's Edit, like the system gallery):
/// "My music" (pick a song on the phone) fixed at the left, then a row that
/// scrolls under it: "No music", the kind's song with "Best match", the
/// other songs (each on a picture of the memory) and the user's own song
/// (when picked). The chosen card has the accent frame. A tap chooses at once
/// ([onChoose]: null = back to the app's choice).
class MemoryMusicStrip extends StatelessWidget {
  const MemoryMusicStrip({
    required this.memory,
    required this.onChoose,
    required this.onPickOwn,
    required this.onClose,
    super.key,
  });

  final StoredMemory memory;
  final ValueChanged<MemoryMusic?> onChoose;
  final VoidCallback onPickOwn;
  final VoidCallback onClose;

  static const double _card = 84;

  @override
  Widget build(BuildContext context) {
    const white = AppColors.mediaBadgeText;
    final current = memory.music;
    final best = musicForKind(memory.kind);
    final pictures = memory.shown;
    String pictureAt(int i) => pictures[i % pictures.length];

    // Scrolls behind the fixed "My music": No music first, then the songs.
    final cards = <Widget>[
      _MusicCard(
        icon: LucideIcons.volumeX,
        title: 'No music',
        selected: current is NoMusic,
        onTap: () => onChoose(const NoMusic()),
      ),
      _MusicCard(
        pictureId: pictureAt(0),
        title: best.title,
        tag: 'Best match',
        selected: current == BundledMusic(best),
        onTap: () => onChoose(null),
      ),
      for (final (i, track)
          in BundledTrack.values.where((t) => t != best).indexed)
        _MusicCard(
          pictureId: pictureAt(i + 1),
          title: track.title,
          selected: current == BundledMusic(track),
          onTap: () => onChoose(BundledMusic(track)),
        ),
      if (current case final OwnMusic own)
        _MusicCard(
          pictureId: pictureAt(BundledTrack.values.length),
          title: own.name,
          tag: 'My music',
          selected: true,
          onTap: onPickOwn,
        ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Music',
                  style: context.textTheme.titleLarge?.copyWith(color: white),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(LucideIcons.chevronDown, color: white),
                onPressed: onClose,
              ),
            ],
          ),
        ),
        SizedBox(
          height: _card,
          child: Row(
            children: [
              // "My music" stays put at the left (seen at once); the rest
              // scroll and slide under it.
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 10),
                child: SizedBox(
                  width: _card,
                  child: _MusicCard(
                    icon: LucideIcons.folderOpen,
                    title: 'My music',
                    selected: false,
                    onTap: onPickOwn,
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(right: 16),
                  itemCount: cards.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (_, i) =>
                      SizedBox(width: _card, child: cards[i]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MusicCard extends StatelessWidget {
  const _MusicCard({
    required this.title,
    required this.selected,
    required this.onTap,
    this.pictureId,
    this.icon,
    this.tag,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  /// A memory picture shown behind the name.
  final String? pictureId;

  /// Instead of a picture (My music / No music).
  final IconData? icon;
  final String? tag;

  @override
  Widget build(BuildContext context) {
    const white = AppColors.mediaBadgeText;
    final scheme = context.colorScheme;
    final picture = pictureId;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? scheme.primary : white.withValues(alpha: 0),
            width: 2.5,
          ),
        ),
        padding: const EdgeInsets.all(2),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (picture != null)
                MediaThumbnail(item: memoryPicture(picture), size: 128)
              else
                ColoredBox(color: white.withValues(alpha: 0.12)),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.mediaScrimTop.withValues(alpha: 0.1),
                      AppColors.mediaScrimTop,
                    ],
                  ),
                ),
              ),
              if (icon case final i?)
                // Above the name (a small card has no room in the middle).
                Align(
                  alignment: const Alignment(0, -0.4),
                  child: Icon(i, size: 24, color: white),
                ),
              if (tag case final t?)
                Positioned(
                  left: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.mediaBadgeFill,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      t,
                      style: context.textTheme.labelSmall?.copyWith(
                        color: white,
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 6,
                right: 6,
                bottom: 6,
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.labelMedium?.copyWith(
                    color: white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
