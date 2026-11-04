import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/platform/app_orientation.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/core/utils/duration_format.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/domain/repositories/video_tools_repository.dart';
import 'package:proalbums/features/gallery/presentation/actions/media_actions.dart';
import 'package:proalbums/features/gallery/presentation/viewer/providers/video_playback_controller.dart';
import 'package:proalbums/features/gallery/presentation/viewer/providers/viewer_providers.dart';
import 'package:proalbums/features/gallery/presentation/viewer/providers/viewer_session_provider.dart';
import 'package:proalbums/features/gallery/presentation/viewer/video_subtitles.dart';
import 'package:proalbums/features/gallery/presentation/viewer/widgets/viewer_video_tools.dart';
import 'package:proalbums/shared/widgets/app_snack_bar.dart';
import 'package:video_player/video_player.dart';

/// What the viewer hands the player page.
typedef VideoPlayerRequest = ({MediaItem item, bool rotated});

/// The full-screen video player (the viewer's "Video tools" button or its
/// rotate button), like the system gallery's:
///  - plays at once; the SAME player as the viewer, so nothing loads again
///    and Back returns to the viewer at the same spot;
///  - bars see-through over the video, tap = show / hide them;
///  - swipe left / right = seek, double tap = play / pause;
///  - up / down on the left half = brightness, right half = volume;
///  - top: frame capture (not for hidden items); bottom: seek bar, play,
///    mute, speed, single loop, crop to fit, rotate, ⋮ (audio track, video
///    quality, subtitles).
class VideoPlayerPage extends ConsumerStatefulWidget {
  const VideoPlayerPage({
    required this.item,
    this.rotationHeld = false,
    super.key,
  });

  final MediaItem item;

  /// The viewer's rotate button already turned the screen: hand it back to
  /// the sensor when this page closes.
  final bool rotationHeld;

  @override
  ConsumerState<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

enum _Gesture { seek, brightness, volume }

enum _More { audio, quality, subtitles }

class _VideoPlayerPageState extends ConsumerState<VideoPlayerPage> {
  // Taken once: `ref` must not be used while the page is being closed.
  late final VideoToolsRepository _tools = ref.read(
    videoToolsRepositoryProvider,
  );
  late final VideoPlayback _playback = ref.read(videoPlaybackProvider.notifier);
  late final bool _vault =
      ref.read(viewerSessionProvider).mediaContext == MediaContext.vault;

  bool _bars = true;
  late bool _rotationHeld = widget.rotationHeld;
  bool? _landscape;

  // --- swipe gestures ---
  _Gesture? _gesture;
  Duration _seekFrom = Duration.zero;
  Duration? _seekTo;
  double _dragDx = 0;
  double _dragDy = 0;
  double _levelFrom = 0;
  double? _shownLevel;
  _Gesture? _shownLevelOf;
  Timer? _levelHide;
  double _brightness = 0.5;
  double _volume = 0.5;
  double _sentVolume = -1;
  bool _brightnessChanged = false;

  // --- ⋮ menu ---
  VideoPlayerController? _controller;
  List<VideoAudioTrack> _audioTracks = const [];
  List<VideoTrack> _videoTracks = const [];
  String? _subtitleName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Opening the player = playing (like the system gallery).
      final state = ref.read(videoPlaybackProvider);
      if (!(state.activeId == widget.item.id && state.isPlaying)) {
        unawaited(_playback.playOrToggle(widget.item));
      }
    });
    unawaited(_readLevels());
  }

  Future<void> _readLevels() async {
    final brightness = await _tools.brightness();
    final volume = await _tools.volume();
    if (!mounted) return;
    _brightness = brightness;
    _volume = volume;
  }

  @override
  void dispose() {
    _levelHide?.cancel();
    // The phone's own brightness again; subtitles only belong to this page.
    if (_brightnessChanged) unawaited(_tools.setBrightness(null));
    if (_subtitleName != null) {
      unawaited(_controller?.setClosedCaptionFile(null));
    }
    if (_rotationHeld) unawaited(AppOrientation.allowRotation());
    super.dispose();
  }

  // --- bars / system UI --------------------------------------------------------

  void _toggleBars() {
    setState(() => _bars = !_bars);
    _applySystemUi();
  }

  /// Portrait: the status bar comes and goes with the bars. Landscape: always
  /// hidden.
  void _applySystemUi() {
    final show = _bars && !(_landscape ?? false);
    SystemChrome.setEnabledSystemUIMode(
      show ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
    );
  }

  void _rotate() {
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    _rotationHeld = true;
    unawaited(AppOrientation.hold(landscape: !landscape));
  }

  // --- gestures ------------------------------------------------------------

  void _seekStart(DragStartDetails details) {
    if (_controller == null) return;
    _gesture = _Gesture.seek;
    _dragDx = 0;
    _seekFrom = _playback.estimatedPosition();
    unawaited(_playback.beginScrub());
    setState(() => _seekTo = _seekFrom);
  }

  void _seekUpdate(DragUpdateDetails details, double width, Duration total) {
    if (_gesture != _Gesture.seek) return;
    _dragDx += details.delta.dx;
    final target = seekTargetFor(
      from: _seekFrom,
      dx: _dragDx,
      width: width,
      total: total,
    );
    _playback.scrubTo(target);
    setState(() => _seekTo = target);
  }

  void _seekEnd() {
    if (_gesture != _Gesture.seek) return;
    _gesture = null;
    unawaited(_playback.endScrub());
    setState(() => _seekTo = null);
  }

  void _levelStart(DragStartDetails details, double width) {
    final brightness = details.localPosition.dx < width / 2;
    _gesture = brightness ? _Gesture.brightness : _Gesture.volume;
    _dragDy = 0;
    _levelFrom = brightness ? _brightness : _volume;
    _levelHide?.cancel();
    setState(() {
      _shownLevelOf = _gesture;
      _shownLevel = _levelFrom;
    });
  }

  void _levelUpdate(DragUpdateDetails details, double height) {
    final gesture = _gesture;
    if (gesture == null || gesture == _Gesture.seek) return;
    _dragDy += details.delta.dy;
    // Half the screen height = the whole range; up = more.
    final value = (_levelFrom - _dragDy / (height * 0.5)).clamp(0.0, 1.0);
    if (gesture == _Gesture.brightness) {
      _brightness = value;
      _brightnessChanged = true;
      unawaited(_tools.setBrightness(value));
    } else {
      _volume = value;
      if ((value - _sentVolume).abs() >= 0.02 || value == 0 || value == 1) {
        _sentVolume = value;
        unawaited(_tools.setVolume(value));
      }
    }
    setState(() => _shownLevel = value);
  }

  void _levelEnd() {
    if (_gesture == _Gesture.volume) unawaited(_tools.setVolume(_volume));
    _gesture = null;
    _levelHide?.cancel();
    _levelHide = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _shownLevel = null);
    });
  }

  // --- frame capture -----------------------------------------------------------

  /// The frame on screen saved to Pictures/Screenshots; a small copy flies to
  /// the top right corner and fades (no message, like the system gallery).
  Future<void> _captureFrame() async {
    final toast = AppToast.of(context);
    final overlay = Overlay.of(context);
    final preview = await _tools.captureFrame(
      widget.item.id,
      _playback.estimatedPosition(),
    );
    if (preview == null) {
      toast.show('Could not save this frame');
      return;
    }
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) =>
          _FrameFlyAway(picture: preview, onDone: () => entry.remove()),
    );
    overlay.insert(entry);
  }

  // --- ⋮ menu ------------------------------------------------------------------

  /// The player of this video arrived: find its audio and video tracks.
  Future<void> _loadTracks(VideoPlayerController controller) async {
    var audio = const <VideoAudioTrack>[];
    var video = const <VideoTrack>[];
    try {
      if (controller.isAudioTrackSupportAvailable()) {
        audio = await controller.getAudioTracks();
      }
      if (controller.isVideoTrackSupportAvailable()) {
        video = await controller.getVideoTracks();
      }
    } on Object {
      // No track lists on this phone: both stay greyed out.
    }
    if (!mounted || controller != _controller) return;
    setState(() {
      _audioTracks = audio;
      _videoTracks = video;
    });
  }

  Future<void> _onMore(_More choice) async {
    final controller = _controller;
    switch (choice) {
      case _More.audio:
        if (controller == null) return;
        final picked = await _chooseFrom(
          title: 'Audio track',
          options: [
            for (final (index, track) in _audioTracks.indexed)
              (
                label: audioTrackLabel(track, index),
                selected: track.isSelected,
                value: track.id,
              ),
          ],
        );
        if (picked is! String) return;
        await controller.selectAudioTrack(picked);
        await _loadTracks(controller);
      case _More.quality:
        if (controller == null) return;
        final anySelected = _videoTracks.any((track) => track.isSelected);
        final picked = await _chooseFrom<VideoTrack?>(
          title: 'Video quality',
          options: [
            (label: 'Auto', selected: !anySelected, value: null),
            for (final (index, track) in _videoTracks.indexed)
              (
                label: videoTrackLabel(track, index),
                selected: track.isSelected,
                value: track,
              ),
          ],
          // "Auto" is a real choice here (null), so the sheet answers a box.
          boxed: true,
        );
        if (picked is! _Box<VideoTrack?>) return;
        await controller.selectVideoTrack(picked.value);
        await _loadTracks(controller);
      case _More.subtitles:
        await _subtitles();
    }
  }

  Future<void> _subtitles() async {
    final controller = _controller;
    if (controller == null) return;
    if (_subtitleName != null) {
      final picked = await _chooseFrom(
        title: 'Subtitles',
        options: [
          (label: 'Off', selected: false, value: 'off'),
          (label: 'Choose another file', selected: false, value: 'file'),
        ],
        subtitle: _subtitleName,
      );
      if (picked is! String) return;
      if (picked == 'off') {
        await controller.setClosedCaptionFile(null);
        if (mounted) setState(() => _subtitleName = null);
        return;
      }
    }
    if (!mounted) return;
    final toast = AppToast.of(context);
    final file = await _tools.pickSubtitle();
    if (file == null || !mounted || controller != _controller) return;
    final captions = parseSubtitleFile(file.name, file.text);
    if (captions == null) {
      toast.show('Choose a .srt or .vtt subtitle file');
      return;
    }
    await controller.setClosedCaptionFile(Future.value(captions));
    if (!mounted) return;
    setState(() => _subtitleName = file.name);
    toast.show('Subtitles on');
  }

  /// A bottom sheet listing [options]; the chosen value, or null. With
  /// [boxed] the answer is wrapped in a [_Box] (for lists that hold null).
  Future<dynamic> _chooseFrom<T>({
    required String title,
    required List<({String label, bool selected, T value})> options,
    String? subtitle,
    bool boxed = false,
  }) {
    return showModalBottomSheet<Object?>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.textTheme.titleMedium),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              for (final option in options)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  title: Text(option.label),
                  trailing: option.selected
                      ? Icon(
                          LucideIcons.check,
                          color: context.colorScheme.primary,
                        )
                      : null,
                  onTap: () =>
                      Navigator.of(context)
                          .pop(boxed ? _Box(option.value) : option.value),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(
      videoPlaybackProvider.select((s) {
        final mine = s.activeId == widget.item.id;
        return (
          controller: mine ? s.controller : null,
          status: mine ? s.status : VideoStatus.loading,
          fill: s.fill,
          duration: mine && s.duration > Duration.zero
              ? s.duration
              : widget.item.duration,
        );
      }),
    );
    final controller = view.controller;
    if (controller != _controller) {
      _controller = controller;
      _audioTracks = const [];
      _videoTracks = const [];
      if (controller != null) unawaited(_loadTracks(controller));
    }

    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    if (landscape != _landscape) {
      _landscape = landscape;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applySystemUi();
      });
    }
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    const onVideo = AppColors.mediaBadgeText;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        // A video player is dark in every theme (like the system player).
        backgroundColor: AppColors.darkCanvasObsidian,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // The video.
            if (controller != null && view.fill)
              ClipRect(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller.value.size.width,
                    height: controller.value.size.height,
                    child: RepaintBoundary(child: VideoPlayer(controller)),
                  ),
                ),
              )
            else if (controller != null)
              Center(
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  child: RepaintBoundary(child: VideoPlayer(controller)),
                ),
              )
            else if (view.status == VideoStatus.error)
              Center(
                child: Text(
                  'This video cannot be played.',
                  style: context.textTheme.bodyMedium?.copyWith(color: onVideo),
                ),
              )
            else
              const Center(child: CircularProgressIndicator()),
            // Subtitles (only when a file was chosen).
            if (controller != null && _subtitleName != null)
              Positioned(
                left: 24,
                right: 24,
                bottom: (_bars ? 150 : 24) + padding.bottom,
                child: ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: controller,
                  builder: (context, value, _) => ClosedCaption(
                    text: value.caption.text,
                    textStyle: context.textTheme.titleMedium?.copyWith(
                      color: onVideo,
                      shadows: const [
                        Shadow(blurRadius: 4, color: AppColors.mediaScrimTop),
                      ],
                    ),
                  ),
                ),
              ),
            // Taps and swipes anywhere on the video.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleBars,
              onDoubleTap: controller == null
                  ? null
                  : () => _playback.playOrToggle(widget.item),
              onHorizontalDragStart: _seekStart,
              onHorizontalDragUpdate: (details) =>
                  _seekUpdate(details, size.width, view.duration),
              onHorizontalDragEnd: (_) => _seekEnd(),
              onHorizontalDragCancel: _seekEnd,
              onVerticalDragStart: (details) =>
                  _levelStart(details, size.width),
              onVerticalDragUpdate: (details) =>
                  _levelUpdate(details, size.height),
              onVerticalDragEnd: (_) => _levelEnd(),
              onVerticalDragCancel: _levelEnd,
            ),
            // Where the seek swipe goes: "00:13 / 00:39" in the middle.
            if (_seekTo != null)
              IgnorePointer(
                child: Center(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: formatVideoDuration(_seekTo!)),
                        TextSpan(
                          text: ' / ${formatVideoDuration(view.duration)}',
                          style: TextStyle(
                            color: onVideo.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                    style: context.textTheme.headlineMedium?.copyWith(
                      color: onVideo,
                      shadows: const [
                        Shadow(blurRadius: 6, color: AppColors.mediaScrimTop),
                      ],
                    ),
                  ),
                ),
              ),
            // Brightness (left) / volume (right) while swiping up or down.
            if (_shownLevel != null && _shownLevelOf != null)
              IgnorePointer(
                child: Align(
                  alignment: _shownLevelOf == _Gesture.brightness
                      ? const Alignment(-0.85, 0)
                      : const Alignment(0.85, 0),
                  child: _LevelPill(
                    level: _shownLevel!,
                    icon: _shownLevelOf == _Gesture.brightness
                        ? LucideIcons.sun
                        : _shownLevel == 0
                        ? LucideIcons.volumeX
                        : _shownLevel! < 0.5
                        ? LucideIcons.volume1
                        : LucideIcons.volume2,
                  ),
                ),
              ),
            _Fading(
              visible: _bars,
              alignment: Alignment.topCenter,
              child: _PlayerTopBar(
                item: widget.item,
                onBack: () {
                  if (context.canPop()) context.pop();
                },
                // Never for hidden items: a saved frame would leave the vault.
                onCapture: _vault || controller == null ? null : _captureFrame,
              ),
            ),
            _Fading(
              visible: _bars,
              alignment: Alignment.bottomCenter,
              child: ViewerVideoTools(
                item: widget.item,
                onRotate: _rotate,
                more: PopupMenuButton<_More>(
                  tooltip: 'More',
                  icon: const Icon(LucideIcons.ellipsisVertical),
                  enabled: controller != null,
                  onSelected: _onMore,
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: _More.audio,
                      // Only when there is something to choose.
                      enabled: _audioTracks.length > 1,
                      child: const Text('Audio track'),
                    ),
                    PopupMenuItem(
                      value: _More.quality,
                      enabled: _videoTracks.length > 1,
                      child: const Text('Video quality'),
                    ),
                    const PopupMenuItem(
                      value: _More.subtitles,
                      child: Text('Subtitles'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A value that may itself be null (an answer from the sheet that says
/// "Auto").
final class _Box<T> {
  const _Box(this.value);
  final T value;
}

/// Where a sideways seek swipe of [dx] pixels lands, starting at [from]: the
/// screen [width] covers the whole video, at most 2 minutes of it (long
/// videos still move precisely).
@visibleForTesting
Duration seekTargetFor({
  required Duration from,
  required double dx,
  required double width,
  required Duration total,
}) {
  if (width <= 0 || total <= Duration.zero) return from;
  final spanMs = math.min(total.inMilliseconds, 120000);
  final target = from.inMilliseconds + (dx / width * spanMs).round();
  return Duration(milliseconds: target.clamp(0, total.inMilliseconds));
}

/// "English", "Hindi · Stereo"… or "Track 2" when the video names nothing.
@visibleForTesting
String audioTrackLabel(VideoAudioTrack track, int index) {
  final name = track.label ?? track.language;
  return (name == null || name.isEmpty) ? 'Track ${index + 1}' : name;
}

/// "1080p", "720p"… or the track's own name.
@visibleForTesting
String videoTrackLabel(VideoTrack track, int index) {
  final height = track.height;
  if (height != null && height > 0) return '${height}p';
  final label = track.label;
  return (label == null || label.isEmpty) ? 'Track ${index + 1}' : label;
}

/// Back, the date and time, and the frame capture, see-through over the
/// video.
class _PlayerTopBar extends StatelessWidget {
  const _PlayerTopBar({
    required this.item,
    required this.onBack,
    required this.onCapture,
  });

  final MediaItem item;
  final VoidCallback onBack;
  final VoidCallback? onCapture;

  @override
  Widget build(BuildContext context) {
    const onVideo = AppColors.mediaBadgeText;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.mediaScrimTop,
            AppColors.mediaScrimTop.withValues(alpha: 0),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kToolbarHeight + 16,
          child: IconTheme.merge(
            data: const IconThemeData(color: onVideo),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Back',
                  icon: const Icon(LucideIcons.chevronLeft),
                  onPressed: onBack,
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat.yMMMd().format(item.createdAt),
                        style: context.textTheme.titleMedium?.copyWith(
                          color: onVideo,
                        ),
                      ),
                      Text(
                        DateFormat.jm().format(item.createdAt),
                        style: context.textTheme.bodySmall?.copyWith(
                          color: onVideo.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                if (onCapture != null)
                  IconButton(
                    tooltip: 'Save this frame',
                    icon: const Icon(LucideIcons.camera),
                    onPressed: onCapture,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The brightness / volume level: a tall rounded pill filling from the
/// bottom, its icon in the middle.
class _LevelPill extends StatelessWidget {
  const _LevelPill({required this.level, required this.icon});

  final double level;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 56,
        height: 160,
        child: Stack(
          children: [
            const Positioned.fill(
              child: ColoredBox(color: AppColors.mediaBadgeFill),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: level.clamp(0.0, 1.0),
                widthFactor: 1,
                child: ColoredBox(
                  color: AppColors.mediaBadgeText.withValues(alpha: 0.85),
                ),
              ),
            ),
            Center(
              child: Icon(
                icon,
                size: 26,
                color: level > 0.5
                    ? AppColors.mediaBadgeFill
                    : AppColors.mediaBadgeText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A bar that fades out (and stops catching touches) when hidden.
class _Fading extends StatelessWidget {
  const _Fading({
    required this.visible,
    required this.alignment,
    required this.child,
  });

  final bool visible;
  final Alignment alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: child,
        ),
      ),
    );
  }
}

/// The saved video frame, small, flying from the middle to the top right
/// corner and fading away (the only sign it was saved, like the system
/// gallery).
class _FrameFlyAway extends StatefulWidget {
  const _FrameFlyAway({required this.picture, required this.onDone});

  final Uint8List picture;
  final VoidCallback onDone;

  @override
  State<_FrameFlyAway> createState() => _FrameFlyAwayState();
}

class _FrameFlyAwayState extends State<_FrameFlyAway>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flight = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    _flight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _flight, curve: Curves.easeInCubic);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: curve,
        builder: (context, child) => Align(
          alignment: Alignment.lerp(
            Alignment.center,
            const Alignment(0.9, -0.85),
            curve.value,
          )!,
          child: Opacity(
            opacity: 1 - curve.value * curve.value,
            child: Transform.scale(scale: 1 - curve.value * 0.8, child: child),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(widget.picture, width: 220, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
