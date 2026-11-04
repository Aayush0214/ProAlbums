import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/compress/domain/compress_repository.dart';
import 'package:proalbums/features/compress/domain/compress_rules.dart';
import 'package:proalbums/features/compress/presentation/compress_progress_card.dart';
import 'package:proalbums/features/compress/presentation/compress_providers.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/images/media_thumbnail_image.dart';
import 'package:proalbums/features/gallery/presentation/providers/share_providers.dart';
import 'package:proalbums/features/gallery/presentation/viewer/providers/viewer_session_provider.dart';
import 'package:proalbums/features/gallery/presentation/widgets/media_thumbnail.dart';
import 'package:proalbums/shared/widgets/app_snack_bar.dart';
import 'package:video_player/video_player.dart';

/// What the viewer hands this page: the video and the chosen size.
typedef CompressVideoRequest = ({MediaItem item, VideoCompressOption option});

/// Compressing a video (like the system gallery): the video dimmed with a
/// "Compressing" card (bar, %, Cancel); when done, "After compression
/// 12.66 MB", the NEW copy plays here, Share sends it, Back goes to the
/// viewer (which then shows the copy).
class CompressVideoPage extends ConsumerStatefulWidget {
  const CompressVideoPage({required this.request, super.key});

  final CompressVideoRequest request;

  @override
  ConsumerState<CompressVideoPage> createState() => _CompressVideoPageState();
}

class _CompressVideoPageState extends ConsumerState<CompressVideoPage> {
  late final CompressRepository _repository = ref.read(
    compressRepositoryProvider,
  );

  int _percent = 0;
  CompressedCopy? _copy;
  bool _working = true;
  VideoPlayerController? _player;

  MediaItem get _item => widget.request.item;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    if (_working) unawaited(_repository.cancelVideo());
    unawaited(_player?.dispose());
    super.dispose();
  }

  Future<void> _start() async {
    final toast = AppToast.of(context);
    final result = await _repository.compressVideo(
      _item.id,
      widget.request.option,
      onProgress: (percent) {
        if (mounted) setState(() => _percent = percent.clamp(0, 100));
      },
    );
    if (!mounted) return;
    switch (result) {
      case VideoCompressed(:final copy):
        await ref.read(compressedMediaRepositoryProvider).remember(copy);
        // Back in the viewer, the copy is shown.
        ref.read(viewerJumpProvider.notifier).to(copy.id);
        toast.show('Compressed video saved');
        final player = VideoPlayerController.contentUri(
          Uri.parse('content://media/external/video/media/${copy.id}'),
        );
        setState(() {
          _working = false;
          _copy = copy;
          _player = player;
        });
        try {
          await player.initialize();
          if (mounted) setState(() {});
        } on Object {
          // The copy is saved; only the preview here cannot play.
        }
      case VideoCompressCancelled():
        _working = false;
        if (mounted && context.canPop()) context.pop();
      case VideoCompressFailed():
        _working = false;
        toast.show('Could not compress this video');
        if (mounted && context.canPop()) context.pop();
    }
  }

  Future<void> _cancel() async {
    // The page closes when the phone says it stopped (see _start).
    await _repository.cancelVideo();
  }

  Future<void> _share() async {
    final copy = _copy;
    if (copy == null) return;
    final toast = AppToast.of(context);
    final result = await ref.read(shareMediaUseCaseProvider)([copy.id]);
    result.match((failure) => toast.show('Could not share this video'), (_) {});
  }

  void _togglePlay() {
    final player = _player;
    if (player == null || !player.value.isInitialized) return;
    setState(() {
      player.value.isPlaying ? player.pause() : player.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    final player = _player;
    final ready = player != null && player.value.isInitialized;
    final copy = _copy;

    return PopScope(
      // While compressing, Back = Cancel (the page closes when it stopped).
      canPop: !_working,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_cancel());
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(LucideIcons.chevronLeft),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: const Text('Compress size'),
          actions: [
            IconButton(
              tooltip: 'Share',
              icon: const Icon(LucideIcons.share2),
              onPressed: copy == null ? null : _share,
            ),
          ],
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (ready)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _togglePlay,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: player.value.aspectRatio,
                    child: VideoPlayer(player),
                  ),
                ),
              )
            else
              Image(
                image: MediaThumbnailImage(
                  id: _item.id,
                  size: 1024,
                  load: thumbnailLoader(ref),
                ),
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),
            if (_working) const ColoredBox(color: AppColors.mediaScrimTop),
            // The play button (paused or not started).
            if (ready && !player.value.isPlaying)
              const IgnorePointer(
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.mediaBadgeFill,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Icon(
                        LucideIcons.play,
                        size: 44,
                        color: AppColors.mediaBadgeText,
                      ),
                    ),
                  ),
                ),
              ),
            if (copy != null)
              Positioned(
                left: 16,
                top: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.mediaBadgeFill,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      'After compression ${formatMegabytes(copy.sizeBytes)}',
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: AppColors.mediaBadgeText,
                      ),
                    ),
                  ),
                ),
              ),
            if (_working)
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  child: CompressProgressCard(
                    title: 'Compressing',
                    percent: _percent,
                    onCancel: _cancel,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
