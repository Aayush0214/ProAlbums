import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/app/router/app_routes.dart';
import 'package:proalbums/core/platform/screen_awake.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/gallery/presentation/images/media_thumbnail_image.dart';
import 'package:proalbums/features/gallery/presentation/viewer/providers/viewer_providers.dart';
import 'package:proalbums/features/gallery/presentation/viewer/viewer_math.dart';
import 'package:proalbums/features/gallery/presentation/widgets/media_thumbnail.dart';
import 'package:proalbums/features/memories/data/memory_repository.dart';
import 'package:proalbums/features/memories/domain/memory_music.dart';
import 'package:proalbums/features/memories/domain/memory_rules.dart';
import 'package:proalbums/features/memories/presentation/memory_export.dart';
import 'package:proalbums/features/memories/presentation/memory_flows.dart';
import 'package:proalbums/features/memories/presentation/memory_music_player.dart';
import 'package:proalbums/features/memories/presentation/memory_providers.dart';
import 'package:proalbums/features/memories/presentation/widgets/memory_cards.dart';
import 'package:proalbums/features/memories/presentation/widgets/memory_music_strip.dart';
import 'package:proalbums/shared/widgets/app_snack_bar.dart';
import 'package:proalbums/shared/widgets/slideshow_player.dart';

/// A memory's video (like the system gallery's): its shown pictures as the
/// app's slideshow (fade + slow zoom, see [SlideshowPlayer]), played at
/// once. Top: X, title + dates, Share, ⋮ (Export video file / Gallery
/// management / Delete memory). Below: time 'mm:ss | mm:ss', the pictures'
/// strip (tap = jump there), Edit, Play / Pause in a progress ring, and
/// the pictures' grid (View Gallery). Music: the memory's (Edit = the
/// Music sheet), in step with the show.
/// Dark in every theme, like the video player.
class MemoryPlayerPage extends ConsumerStatefulWidget {
  const MemoryPlayerPage({required this.memoryId, super.key});

  final int memoryId;

  @override
  ConsumerState<MemoryPlayerPage> createState() => _MemoryPlayerPageState();
}

class _MemoryPlayerPageState extends ConsumerState<MemoryPlayerPage>
    with WidgetsBindingObserver {
  /// The memory's music, in step with the show.
  final MemoryMusicPlayer _music = MemoryMusicPlayer();
  MemoryMusic? _loadedMusic;

  static const SlideshowOptions _options = SlideshowOptions(
    slide: memorySlide,
    fade: memoryFade,
    zoomTo: 1.15,
  );

  bool _paused = false;
  bool _finished = false;

  /// Where the show starts (a tap on the strip starts it again there).
  int _start = 0;
  int _index = 0;

  /// A new player for every jump / replay.
  int _run = 0;

  /// Time inside the current picture (the clock below the show).
  final Stopwatch _inPicture = Stopwatch();
  Timer? _tick;

  /// One provider per picture (the slideshow precaches the same one it
  /// then shows).
  final Map<String, ImageProvider> _images = {};

  ImageProvider _imageOf(String id) => _images.putIfAbsent(id, () {
    final media = MediaQuery.of(context);
    return MediaThumbnailImage(
      id: id,
      size: viewerImageLongEdge(
        media.size.longestSide * media.devicePixelRatio,
      ),
      load: (id, size) async {
        final result = await ref.read(loadDisplayImageUseCaseProvider)(
          id: id,
          maxLongEdge: size,
        );
        return result.fold((failure) => null, (bytes) => bytes);
      },
    );
  });

  final ScrollController _strip = ScrollController();
  static const double _stripItem = 56;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(ScreenAwake.keepOn(on: true));
    _inPicture.start();
    _tick = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted && !_paused && !_finished) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    _strip.dispose();
    unawaited(_music.dispose());
    unawaited(ScreenAwake.keepOn(on: false));
    super.dispose();
  }

  /// The app went to the background: the show and its music stop.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && !_paused && !_finished) {
      _pause();
    }
  }

  /// Plays [music] when the memory's music changed (first time, or a new
  /// choice in the editor). A picked song that cannot be opened any more
  /// (deleted) says so and plays nothing.
  void _syncMusic(MemoryMusic music, Duration videoLength) {
    if (music == _loadedMusic) return;
    _loadedMusic = music;
    final toast = AppToast.of(context);
    unawaited(
      _music
          .load(
            music,
            play: !_paused && !_finished,
            // The user's own song: only its chosen part, as long as the video.
            partMs: music is OwnMusic ? videoLength : null,
          )
          .then((ok) {
            if (!ok && mounted) toast.show('This song cannot be played');
          }),
    );
  }

  /// The music cards are open (Edit).
  bool _editing = false;

  void _openEditor() {
    _pause();
    setState(() => _editing = true);
  }

  /// A card was chosen: saved, the cards close, the show and the new song
  /// start from the beginning.
  Future<void> _chooseMusic(MemoryMusic? music) async {
    setState(() => _editing = false);
    await ref.read(memoryStoreProvider).setMusic(widget.memoryId, music);
    ref.read(memoryScanProvider.notifier).changed();
    if (mounted) _jump(0);
  }

  /// "My music": a song from the phone, then its part (as long as the
  /// video), then as [_chooseMusic].
  Future<void> _pickOwnMusic(Duration videoLength) async {
    final picked = await ref.read(memoryPlatformProvider).pickAudio();
    if (picked == null || !mounted) return;
    final start = await context.push<int>(
      AppRoutes.memoryMusicTrim,
      extra: (
        uri: picked.uri,
        name: picked.name,
        videoMs: videoLength.inMilliseconds,
      ),
    );
    if (start == null || !mounted) return;
    await _chooseMusic(OwnMusic(picked.uri, picked.name, startMs: start));
  }

  void _pause() {
    setState(() => _paused = true);
    _inPicture.stop();
    unawaited(_music.pause());
  }

  void _onIndex(int index) {
    _index = index;
    _inPicture
      ..reset()
      ..start();
    if (_paused) _inPicture.stop();
    if (mounted) setState(() {});
    // Keep the current picture in the middle of the strip.
    if (_strip.hasClients) {
      final target =
          (index * (_stripItem + 6)) -
          (_strip.position.viewportDimension - _stripItem) / 2;
      unawaited(
        _strip.animateTo(
          target.clamp(0, _strip.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        ),
      );
    }
  }

  void _playPause() {
    if (_finished) {
      _jump(0);
      return;
    }
    if (_paused) {
      setState(() => _paused = false);
      _inPicture.start();
      unawaited(_music.play());
    } else {
      _pause();
    }
  }

  void _jump(int index) {
    setState(() {
      _start = index;
      _index = index;
      _run++;
      _finished = false;
      _paused = false;
      _inPicture
        ..reset()
        ..start();
    });
    // From the start = the song from its start too.
    if (index == 0) unawaited(_music.restart());
    unawaited(_music.play());
  }

  void _finish() {
    setState(() => _finished = true);
    unawaited(_music.pause());
  }

  /// Share = the memory as a video (made first), like the system gallery.
  Future<void> _share(StoredMemory memory) async {
    _pause();
    await shareMemoryVideo(context, ref, memory);
  }

  Future<void> _delete() async {
    _pause();
    if (await deleteMemories(context, ref, [widget.memoryId]) && mounted) {
      context.pop();
    }
  }

  String _clock(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:'
      '${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final memory = ref.watch(storedMemoryProvider(widget.memoryId));
    final shown = memory?.shown ?? const <String>[];
    final size = MediaQuery.sizeOf(context);

    final total = memoryPerPicture * shown.length;
    if (memory != null) _syncMusic(memory.music, total);
    final inPicture = _inPicture.elapsed > memoryPerPicture
        ? memoryPerPicture
        : _inPicture.elapsed;
    final position = _finished ? total : memoryPerPicture * _index + inPicture;
    final progress = total == Duration.zero
        ? 0.0
        : position.inMilliseconds / total.inMilliseconds;

    const white = AppColors.mediaBadgeText;
    final secondary = white.withValues(alpha: 0.6);

    return PopScope(
      // Back closes the music cards first.
      canPop: !_editing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _editing = false);
      },
      child: Scaffold(
        backgroundColor: AppColors.darkCanvasObsidian,
        body: SafeArea(
          child: Column(
            children: [
              // Top bar.
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(LucideIcons.x, color: white),
                      onPressed: () => context.pop(),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            memory?.title ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.textTheme.titleLarge?.copyWith(
                              color: white,
                            ),
                          ),
                          if (memory != null)
                            Text(
                              memoryDateText(
                                memory.kind,
                                memory.startMs,
                                memory.endMs,
                              ),
                              style: context.textTheme.bodySmall?.copyWith(
                                color: secondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Share',
                      icon: const Icon(LucideIcons.share2, color: white),
                      onPressed: memory == null || shown.isEmpty
                          ? null
                          : () => unawaited(_share(memory)),
                    ),
                    PopupMenuButton<void>(
                      tooltip: 'More',
                      // The show waits while the menu is open.
                      onOpened: () {
                        if (!_paused && !_finished) _pause();
                      },
                      icon: const Icon(
                        LucideIcons.ellipsisVertical,
                        color: white,
                      ),
                      itemBuilder: (_) => [
                        PopupMenuItem<void>(
                          onTap: memory == null
                              ? null
                              : () {
                                  _pause();
                                  unawaited(
                                    exportMemoryVideo(context, ref, memory),
                                  );
                                },
                          child: const Text('Export video file'),
                        ),
                        PopupMenuItem<void>(
                          onTap: () {
                            _pause();
                            manageMemory(context, widget.memoryId);
                          },
                          child: const Text('Gallery management'),
                        ),
                        PopupMenuItem<void>(
                          onTap: () => unawaited(_delete()),
                          child: const Text('Delete memory'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // The show (tap = play / pause).
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _playPause,
                  child: shown.isEmpty
                      ? const SizedBox.expand()
                      // The slow zoom stays inside the show (it covered the
                      // bars on tall pictures).
                      : ClipRect(
                          child: SlideshowPlayer(
                            key: ValueKey('$_run:${shown.join(',')}'),
                            count: shown.length,
                            startIndex: _start.clamp(0, shown.length - 1),
                            paused: _paused,
                            options: _options,
                            imageAt: (i) => _imageOf(shown[i]),
                            onIndex: _onIndex,
                            onFinished: _finish,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: _clock(position),
                      style: const TextStyle(color: white),
                    ),
                    TextSpan(
                      text: '  |  ${_clock(total)}',
                      style: TextStyle(color: secondary),
                    ),
                  ],
                ),
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              // The pictures; the current one is bigger.
              SizedBox(
                height: _stripItem + 12,
                child: ListView.separated(
                  controller: _strip,
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(
                    horizontal: (size.width - _stripItem) / 2,
                  ),
                  itemCount: shown.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (context, i) {
                    final current = i == _index;
                    return GestureDetector(
                      onTap: () => _jump(i),
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: current ? _stripItem : _stripItem - 12,
                          height: current ? _stripItem + 12 : _stripItem,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: current
                                ? Border.all(color: white, width: 2)
                                : null,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: MediaThumbnail(
                            item: memoryPicture(shown[i]),
                            size: 128,
                            compactBadge: true,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              // Edit: the music cards in place of the buttons (they close
              // when a card is chosen).
              if (_editing && memory != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: MemoryMusicStrip(
                    memory: memory,
                    onChoose: (music) => unawaited(_chooseMusic(music)),
                    onPickOwn: () => unawaited(_pickOwnMusic(total)),
                    onClose: () => setState(() => _editing = false),
                  ),
                )
              else
                // Edit, Play / Pause, the pictures.
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Edit',
                        icon: const Icon(LucideIcons.squarePen, color: white),
                        onPressed: memory == null ? null : _openEditor,
                      ),
                      const Spacer(),
                      SizedBox.square(
                        dimension: 64,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox.square(
                              dimension: 60,
                              child: CircularProgressIndicator(
                                value: progress.clamp(0.0, 1.0),
                                strokeWidth: 3,
                                color: context.colorScheme.primary,
                                backgroundColor: white.withValues(alpha: 0.2),
                              ),
                            ),
                            IconButton(
                              tooltip: _paused || _finished ? 'Play' : 'Pause',
                              iconSize: 30,
                              onPressed: shown.isEmpty ? null : _playPause,
                              icon: Icon(
                                _finished
                                    ? LucideIcons.rotateCcw
                                    : _paused
                                    ? LucideIcons.play
                                    : LucideIcons.pause,
                                color: white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Pictures',
                        icon: const Icon(LucideIcons.layoutGrid, color: white),
                        onPressed: memory == null
                            ? null
                            : () {
                                _pause();
                                viewMemoryGallery(context, memory);
                              },
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
