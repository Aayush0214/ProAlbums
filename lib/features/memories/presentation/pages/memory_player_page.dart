import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/platform/screen_awake.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/gallery/presentation/images/media_thumbnail_image.dart';
import 'package:proalbums/features/gallery/presentation/providers/share_providers.dart';
import 'package:proalbums/features/gallery/presentation/viewer/providers/viewer_providers.dart';
import 'package:proalbums/features/gallery/presentation/viewer/viewer_math.dart';
import 'package:proalbums/features/gallery/presentation/widgets/media_thumbnail.dart';
import 'package:proalbums/features/memories/domain/memory_rules.dart';
import 'package:proalbums/features/memories/presentation/memory_flows.dart';
import 'package:proalbums/features/memories/presentation/memory_providers.dart';
import 'package:proalbums/features/memories/presentation/widgets/memory_cards.dart';
import 'package:proalbums/shared/widgets/app_snack_bar.dart';
import 'package:proalbums/shared/widgets/slideshow_player.dart';

/// A memory's video (like the system gallery's): its shown pictures as the
/// app's slideshow (fade + slow zoom, see [SlideshowPlayer]), played at
/// once. Top: X, title + dates, Share, ⋮ (Export video file / Gallery
/// management / Delete memory). Below: time 'mm:ss | mm:ss', the pictures'
/// strip (tap = jump there), Edit, Play / Pause in a progress ring, and
/// the pictures' grid (View Gallery). Music and the video file come with
/// the editor (phase 5). Dark in every theme, like the video player.
class MemoryPlayerPage extends ConsumerStatefulWidget {
  const MemoryPlayerPage({required this.memoryId, super.key});

  final int memoryId;

  @override
  ConsumerState<MemoryPlayerPage> createState() => _MemoryPlayerPageState();
}

class _MemoryPlayerPageState extends ConsumerState<MemoryPlayerPage> {
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
    unawaited(ScreenAwake.keepOn(on: true));
    _inPicture.start();
    _tick = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted && !_paused && !_finished) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _strip.dispose();
    unawaited(ScreenAwake.keepOn(on: false));
    super.dispose();
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
    setState(() => _paused = !_paused);
    _paused ? _inPicture.stop() : _inPicture.start();
  }

  void _jump(int index) => setState(() {
    _start = index;
    _index = index;
    _run++;
    _finished = false;
    _paused = false;
    _inPicture
      ..reset()
      ..start();
  });

  Future<void> _share(List<String> ids) async {
    final toast = AppToast.of(context);
    final result = await ref.read(shareMediaUseCaseProvider)(ids);
    result.match(
      (failure) => toast.show('Could not share the selected items.'),
      (_) {},
    );
  }

  Future<void> _delete() async {
    setState(() => _paused = true);
    _inPicture.stop();
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
    final inPicture = _inPicture.elapsed > memoryPerPicture
        ? memoryPerPicture
        : _inPicture.elapsed;
    final position = _finished ? total : memoryPerPicture * _index + inPicture;
    final progress = total == Duration.zero
        ? 0.0
        : position.inMilliseconds / total.inMilliseconds;

    const white = AppColors.mediaBadgeText;
    final secondary = white.withValues(alpha: 0.6);

    return Scaffold(
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
                    onPressed: shown.isEmpty
                        ? null
                        : () => unawaited(_share(shown)),
                  ),
                  PopupMenuButton<void>(
                    tooltip: 'More',
                    icon: const Icon(
                      LucideIcons.ellipsisVertical,
                      color: white,
                    ),
                    itemBuilder: (_) => [
                      PopupMenuItem<void>(
                        onTap: () =>
                            showComingSoon(context, 'Export video file'),
                        child: const Text('Export video file'),
                      ),
                      PopupMenuItem<void>(
                        onTap: () {
                          setState(() => _paused = true);
                          _inPicture.stop();
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
                          onFinished: () => setState(() => _finished = true),
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
            // Edit, Play / Pause, the pictures.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Edit',
                    icon: const Icon(LucideIcons.squarePen, color: white),
                    onPressed: () => showComingSoon(context, 'Memory editor'),
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
                            setState(() => _paused = true);
                            _inPicture.stop();
                            viewMemoryGallery(context, memory);
                          },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
