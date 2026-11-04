import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/core/utils/duration_format.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/viewer/providers/video_playback_controller.dart';
import 'package:proalbums/shared/widgets/app_snack_bar.dart';

/// The speeds offered (1 = normal).
const List<double> videoSpeeds = [0.5, 0.75, 1, 1.25, 1.5, 2];

/// "1.0x", "1.25x", "0.5x".
String speedLabel(double speed) =>
    '${speed == speed.roundToDouble() ? speed.toStringAsFixed(1) : speed}x';

/// The video player's bottom controls, see-through over the video:
/// "00:05 / 00:10", a seek bar, then Play / Pause, mute, speed, single loop,
/// crop to fit, rotate and [more].
class ViewerVideoTools extends ConsumerStatefulWidget {
  const ViewerVideoTools({
    required this.item,
    required this.onRotate,
    required this.more,
    super.key,
  });

  final MediaItem item;
  final VoidCallback onRotate;

  /// The ⋮ button with its menu (audio track, quality, subtitles).
  final Widget more;

  @override
  ConsumerState<ViewerVideoTools> createState() => _ViewerVideoToolsState();
}

class _ViewerVideoToolsState extends ConsumerState<ViewerVideoTools> {
  /// The time and the bar move 4 times a second while playing (cheap).
  Timer? _ticker;

  /// While the finger is on the bar: where it is.
  Duration? _dragging;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted && _dragging == null) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  VideoPlayback get _playback => ref.read(videoPlaybackProvider.notifier);

  Future<void> _toggleLoop() async {
    final toast = AppToast.of(context);
    final on = await _playback.toggleLooping();
    toast.show(on ? 'Single loop on' : 'Single loop off');
  }

  void _toggleFill() {
    final on = _playback.toggleFill();
    AppToast.of(context).show(on ? 'Crop to fit' : 'Fit to screen');
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(
      videoPlaybackProvider.select((s) {
        final mine = s.activeId == widget.item.id;
        return (
          ready: mine && s.controller != null,
          playing: mine && s.isPlaying,
          duration: mine && s.duration > Duration.zero
              ? s.duration
              : widget.item.duration,
          looping: s.looping,
          speed: s.speed,
          fill: s.fill,
          muted: s.muted,
        );
      }),
    );
    final total = view.duration;
    final now =
        _dragging ??
        (view.ready ? _playback.estimatedPosition() : Duration.zero);
    final position = now > total ? total : now;
    final maxMs = total.inMilliseconds.toDouble().clamp(1.0, double.infinity);
    // Light on the dark video, in any theme (like the system player).
    const onVideo = AppColors.mediaBadgeText;
    final textStyle = context.textTheme.bodyMedium?.copyWith(color: onVideo);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            AppColors.mediaScrimTop,
            AppColors.mediaScrimTop.withValues(alpha: 0),
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 24, 8, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '${formatVideoDuration(position)} / '
                  '${formatVideoDuration(total)}',
                  style: textStyle,
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8,
                  ),
                  activeTrackColor: onVideo,
                  thumbColor: onVideo,
                  inactiveTrackColor: onVideo.withValues(alpha: 0.35),
                  disabledActiveTrackColor: onVideo,
                  disabledThumbColor: onVideo,
                  disabledInactiveTrackColor: onVideo.withValues(alpha: 0.35),
                ),
                child: Slider(
                  max: maxMs,
                  value: position.inMilliseconds.toDouble().clamp(0, maxMs),
                  onChangeStart: view.ready
                      ? (value) {
                          _playback.beginScrub();
                          setState(
                            () => _dragging = Duration(
                              milliseconds: value.round(),
                            ),
                          );
                        }
                      : null,
                  onChanged: view.ready
                      ? (value) {
                          final target = Duration(milliseconds: value.round());
                          _playback.scrubTo(target);
                          setState(() => _dragging = target);
                        }
                      : null,
                  onChangeEnd: view.ready
                      ? (_) {
                          _playback.endScrub();
                          setState(() => _dragging = null);
                        }
                      : null,
                ),
              ),
              IconTheme.merge(
                data: const IconThemeData(color: onVideo),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: view.playing ? 'Pause' : 'Play',
                      icon: Icon(
                        view.playing ? LucideIcons.pause : LucideIcons.play,
                      ),
                      onPressed: () => _playback.playOrToggle(widget.item),
                    ),
                    IconButton(
                      tooltip: view.muted ? 'Sound on' : 'Mute',
                      icon: Icon(
                        view.muted ? LucideIcons.volumeX : LucideIcons.volume2,
                      ),
                      onPressed: _playback.toggleMute,
                    ),
                    const Spacer(),
                    PopupMenuButton<double>(
                      tooltip: 'Playback speed',
                      initialValue: view.speed,
                      onSelected: _playback.setSpeed,
                      itemBuilder: (context) => [
                        for (final speed in videoSpeeds)
                          PopupMenuItem(
                            value: speed,
                            child: Text(speedLabel(speed)),
                          ),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(LucideIcons.gauge),
                            const SizedBox(width: 4),
                            Text(
                              speedLabel(view.speed),
                              style: context.textTheme.labelMedium?.copyWith(
                                color: onVideo,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: view.looping
                          ? 'Single loop on'
                          : 'Single loop off',
                      icon: Icon(
                        view.looping
                            ? LucideIcons.repeat1
                            : LucideIcons.repeatOff,
                      ),
                      onPressed: _toggleLoop,
                    ),
                    IconButton(
                      tooltip: view.fill ? 'Fit to screen' : 'Crop to fit',
                      icon: Icon(
                        view.fill ? LucideIcons.shrink : LucideIcons.scan,
                      ),
                      onPressed: _toggleFill,
                    ),
                    IconButton(
                      tooltip: 'Rotate',
                      icon: const Icon(LucideIcons.rotateCwSquare),
                      onPressed: widget.onRotate,
                    ),
                    widget.more,
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
