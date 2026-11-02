import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/gallery/presentation/viewer/providers/video_playback_controller.dart';
import 'package:proalbums/features/gallery/presentation/viewer/providers/viewer_providers.dart';
import 'package:proalbums/features/gallery/presentation/viewer/video_math.dart';

/// One frame of an OPENED video in the filmstrip.
///
/// Taking a frame out of a video takes a moment (the phone starts a decoder
/// for each one). Until it is ready the video's own small picture is shown, so
/// there is never an empty black box.
class VideoFrameTile extends ConsumerStatefulWidget {
  const VideoFrameTile({
    required this.id,
    required this.position,
    required this.placeholder,
    super.key,
  });

  /// Size (longer side, pixels) of the frames. Also used by the preloader, so
  /// both ask for exactly the same picture.
  static const int frameSize = 224;

  final String id;
  final Duration position;
  final ImageProvider placeholder;

  @override
  ConsumerState<VideoFrameTile> createState() => _VideoFrameTileState();
}

class _VideoFrameTileState extends ConsumerState<VideoFrameTile> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(VideoFrameTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.position != widget.position || oldWidget.id != widget.id) {
      _bytes = null;
      _load();
    }
  }

  Future<void> _load() async {
    final id = widget.id;
    final position = widget.position;
    // While the video jumps or settles, the thumbnail stays and the frame
    // comes a moment later (the video gets the decoder first).
    await ref.read(videoPlaybackProvider.notifier).waitForQuiet();
    if (!mounted || id != widget.id || position != widget.position) return;
    final result = await ref.read(getVideoFrameUseCaseProvider)(
      id: id,
      position: position,
      size: VideoFrameTile.frameSize,
    );
    final bytes = result.fold((failure) => null, (bytes) => bytes);
    if (!mounted || bytes == null) return;
    if (id != widget.id || position != widget.position) return; // reused
    setState(() => _bytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    return SizedBox(
      width: kVideoFrameWidth,
      height: kVideoFrameHeight,
      child: bytes == null
          ? Image(
              image: widget.placeholder,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) =>
                  ColoredBox(color: context.colorScheme.surfaceContainerHigh),
            )
          : Image.memory(
              bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              filterQuality: FilterQuality.low,
            ),
    );
  }
}

/// "00:31/00:39" while the finger moves through the video.
class ScrubTimeBubble extends StatelessWidget {
  const ScrubTimeBubble({required this.time, required this.total, super.key});

  final Duration time;
  final Duration total;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colorScheme.inverseSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: formatClock(time),
                style: style?.copyWith(color: context.colorScheme.onInverseSurface),
              ),
              TextSpan(
                text: '/${formatClock(total)}',
                style: style?.copyWith(
                  color: context.colorScheme.onInverseSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
