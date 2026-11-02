import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:proalbums/core/logging/app_logger.dart';
import 'package:proalbums/core/platform/screen_awake.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/viewer/providers/viewer_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:video_player/video_player.dart';

part 'video_playback_controller.g.dart';

enum VideoStatus { idle, loading, ready, error }

/// What the screen needs to know about the video that is open.
///
/// The playing POSITION is not in here on purpose: it changes many times a
/// second, and everything that listens to this state would rebuild. The strip
/// asks [VideoPlayback.estimatedPosition] on its own instead.
@immutable
final class VideoPlaybackState {
  const VideoPlaybackState({
    this.activeId,
    this.controller,
    this.status = VideoStatus.idle,
    this.isPlaying = false,
    this.isScrubbing = false,
    this.started = false,
    this.duration = Duration.zero,
  });

  /// The video that was opened (null = no video is open).
  final String? activeId;
  final VideoPlayerController? controller;
  final VideoStatus status;
  final bool isPlaying;

  /// The finger is on the strip, moving through the video.
  final bool isScrubbing;

  /// Play was asked for. Before that the player is only PREPARED (ready to
  /// start at once, showing the first picture), and the screen looks like a
  /// video that has not been started.
  final bool started;
  final Duration duration;

  VideoPlaybackState copyWith({
    VideoStatus? status,
    bool? isPlaying,
    bool? isScrubbing,
    bool? started,
    Duration? duration,
  }) =>
      VideoPlaybackState(
        activeId: activeId,
        controller: controller,
        status: status ?? this.status,
        isPlaying: isPlaying ?? this.isPlaying,
        isScrubbing: isScrubbing ?? this.isScrubbing,
        started: started ?? this.started,
        duration: duration ?? this.duration,
      );
}

/// Owns THE video player of the viewer. Only one video plays at a time, and
/// the bars, the strip and the page all talk to this one object.
///
/// Auto-disposed: when the viewer closes, the player is released.
@riverpod
class VideoPlayback extends _$VideoPlayback {
  VideoPlayerController? _controller;

  // video_player tells us the position only about twice a second. To move the
  // strip smoothly we remember the last known position and the time it came,
  // and guess the rest (see estimatedPosition).
  final Stopwatch _clock = Stopwatch()..start();
  Duration _anchor = Duration.zero;
  int _anchorAtMs = 0;
  Duration _lastReported = Duration.zero;

  bool _wasPlayingBeforeScrub = false;

  // After the finger lets go, the video needs the phone's video decoder for
  // itself for a moment (see waitForQuiet).
  Timer? _settleTimer;
  // video_player's seekTo() answers after ~1 ms: it only HANDS the jump to the
  // player, the real work (starting the decoder from the previous keyframe)
  // happens afterwards. So jumps must be rationed by the clock: sending one for
  // every scroll event buried the player (the log showed ~850 jumps in a few
  // drags) and the final one waited in line.
  static const Duration _seekGap = Duration(milliseconds: 150);
  Duration? _pendingSeek;
  Timer? _seekTimer;
  int _lastSeekAtMs = -1000;
  int _seeksThisDrag = 0;

  // Bumped on every open/close: an answer that arrives late (the user already
  // swiped away) sees a different number and throws itself away.
  int _generation = 0;

  @override
  VideoPlaybackState build() {
    ref.onDispose(() {
      _generation++;
      _detach();
    });
    return const VideoPlaybackState();
  }

  /// Play this item: starts it if it is not open yet, else play / pause.
  Future<void> playOrToggle(MediaItem item) {
    if (state.activeId == item.id) {
      if (_controller != null) {
        // Prepared earlier (see prepare): play now, nothing to wait for.
        if (!state.started) state = state.copyWith(started: true);
        return togglePlay();
      }
      if (state.status == VideoStatus.loading) {
        // Still getting ready: it plays the moment it is.
        if (!state.started) state = state.copyWith(started: true);
        return Future<void>.value();
      }
    }
    return _begin(item, play: true);
  }

  /// Get the player ready WITHOUT playing, while the person is still looking
  /// at the picture, so pressing play starts at once.
  Future<void> prepare(MediaItem item) {
    if (state.activeId == item.id && state.status != VideoStatus.error) {
      return Future<void>.value();
    }
    return _begin(item, play: false);
  }

  Future<void> _begin(MediaItem item, {required bool play}) async {
    final generation = ++_generation;
    _detach();
    _setAnchor(Duration.zero);
    state = VideoPlaybackState(
      activeId: item.id,
      status: VideoStatus.loading,
      started: play,
      duration: item.duration,
    );

    final clock = Stopwatch()..start();
    final result = await ref.read(resolveVideoSourceUseCaseProvider)(item.id);
    if (!ref.mounted || generation != _generation) return;
    final resolvedMs = clock.elapsedMilliseconds;
    final path = result.fold((failure) => null, (path) => path);
    if (path == null) {
      _fail(item.id);
      return;
    }

    final controller = path.startsWith('content://')
        ? VideoPlayerController.contentUri(Uri.parse(path))
        : VideoPlayerController.file(File(path));
    try {
      await controller.initialize();
    } on Object catch (error, stackTrace) {
      AppLogger.e('Video could not start', error: error, stackTrace: stackTrace);
      await controller.dispose();
      if (ref.mounted && generation == _generation) _fail(item.id);
      return;
    }
    if (!ref.mounted || generation != _generation) {
      await controller.dispose();
      return;
    }

    _controller = controller..addListener(_onValue);
    // `started` may have turned true while we were getting ready.
    final started = state.started;
    state = VideoPlaybackState(
      activeId: item.id,
      controller: controller,
      status: VideoStatus.ready,
      started: started,
      duration: controller.value.duration,
    );
    // Debug aid: where the time goes between "play" and the first picture.
    AppLogger.d(
      '[video] ready in ${clock.elapsedMilliseconds} ms '
      '(address $resolvedMs ms, player ${clock.elapsedMilliseconds - resolvedMs} ms, '
      'started: $started)',
    );
    if (started) await controller.play();
  }

  Future<void> togglePlay() async {
    final controller = _controller;
    if (controller == null) return;
    final value = controller.value;
    if (value.isPlaying) {
      await controller.pause();
      return;
    }
    // At the end: play again from the beginning.
    if (value.duration > Duration.zero &&
        value.position >= value.duration - const Duration(milliseconds: 250)) {
      _setAnchor(Duration.zero);
      await controller.seekTo(Duration.zero);
    }
    await controller.play();
  }

  Future<void> pause() async => _controller?.pause();

  /// The video is not needed any more (another page, the viewer closed).
  void close() {
    if (state.activeId == null) return;
    _generation++;
    _detach();
    state = const VideoPlaybackState();
  }

  /// Best guess of where the video is RIGHT NOW (smooth, unlike the plugin).
  Duration estimatedPosition() {
    if (!state.isPlaying) return _anchor;
    final passed = Duration(milliseconds: _clock.elapsedMilliseconds - _anchorAtMs);
    final guess = _anchor + passed;
    return guess > state.duration ? state.duration : guess;
  }

  // --- sharing the phone's video decoder ---------------------------------------

  /// True while the video itself needs the decoder: the finger is moving it,
  /// a jump is being made, or it has only just started playing from a new spot.
  bool get isBusy =>
      state.isScrubbing || (_settleTimer?.isActive ?? false);

  /// Taking frames out of the video for the strip uses the SAME hardware video
  /// decoder as playing it (a 4K phone has very few of them), so frames wait
  /// here until the video is not in the middle of a jump. This is what made
  /// the video start late after sliding the strip.
  Future<void> waitForQuiet() async {
    while (isBusy && ref.mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  // --- scrubbing (dragging the strip) -------------------------------------

  Future<void> beginScrub() async {
    final controller = _controller;
    if (controller == null) return;
    _wasPlayingBeforeScrub = controller.value.isPlaying;
    state = state.copyWith(isScrubbing: true);
    if (_wasPlayingBeforeScrub) await controller.pause();
  }

  void scrubTo(Duration position) {
    if (_controller == null) return;
    final target = _clamp(position);
    _setAnchor(target);
    _pendingSeek = target;

    // At most one jump per _seekGap: now if it has been quiet long enough,
    // else once the gap is over (with the NEWEST wanted position by then).
    final wait =
        _seekGap.inMilliseconds - (_clock.elapsedMilliseconds - _lastSeekAtMs);
    if (wait <= 0) {
      _sendPendingSeek();
    } else {
      _seekTimer ??= Timer(Duration(milliseconds: wait), _sendPendingSeek);
    }
  }

  Future<void> endScrub() async {
    final lifted = Stopwatch()..start();
    final controller = _controller;
    if (state.isScrubbing) state = state.copyWith(isScrubbing: false);
    // The final position goes out at once (no waiting for the gap), and the
    // player does the jump and then plays, in that order.
    _sendPendingSeek();
    AppLogger.d('[video] drag ended: $_seeksThisDrag jumps sent');
    _seeksThisDrag = 0;
    if (ref.mounted &&
        controller != null &&
        controller == _controller &&
        _wasPlayingBeforeScrub) {
      await controller.play();
      // Debug aid: finger up -> play() accepted. The picture can still need a
      // moment after this (the decoder starts from the previous keyframe).
      AppLogger.d('[video] finger up -> play ${lifted.elapsedMilliseconds} ms');
    }
    _wasPlayingBeforeScrub = false;
    _settleTimer?.cancel();
    _settleTimer = Timer(const Duration(milliseconds: 1500), () {});
  }

  // --- internals -------------------------------------------------------------

  void _sendPendingSeek() {
    _seekTimer?.cancel();
    _seekTimer = null;
    final target = _pendingSeek;
    final controller = _controller;
    if (target == null || controller == null) return;
    _pendingSeek = null;
    _lastSeekAtMs = _clock.elapsedMilliseconds;
    _seeksThisDrag++;
    unawaited(controller.seekTo(target));
  }

  void _onValue() {
    final controller = _controller;
    if (controller == null || !ref.mounted) return;
    final value = controller.value;

    if (value.hasError) {
      AppLogger.e('Video error: ${value.errorDescription}');
      state = state.copyWith(status: VideoStatus.error, isPlaying: false);
      return;
    }
    if (value.position != _lastReported) {
      _lastReported = value.position;
      _setAnchor(value.position);
    }
    if (value.isPlaying != state.isPlaying) {
      _setAnchor(value.position);
      state = state.copyWith(isPlaying: value.isPlaying);
      // Screen stays on exactly while the video plays.
      unawaited(ScreenAwake.keepOn(on: value.isPlaying));
    }
  }

  void _setAnchor(Duration position) {
    _anchor = position;
    _anchorAtMs = _clock.elapsedMilliseconds;
  }

  Duration _clamp(Duration position) {
    if (position < Duration.zero) return Duration.zero;
    return position > state.duration ? state.duration : position;
  }

  void _fail(String id) {
    state = VideoPlaybackState(activeId: id, status: VideoStatus.error);
  }

  void _detach() {
    final controller = _controller;
    _controller = null;
    _pendingSeek = null;
    _seekTimer?.cancel();
    _seekTimer = null;
    _settleTimer?.cancel();
    controller?.removeListener(_onValue);
    unawaited(controller?.dispose());
    unawaited(ScreenAwake.keepOn(on: false));
  }
}
