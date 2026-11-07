import 'dart:async';

import 'package:proalbums/core/logging/app_logger.dart';
import 'package:proalbums/features/memories/domain/memory_music.dart';
import 'package:video_player/video_player.dart';

/// Plays a memory's music with the app's media player (the same ExoPlayer
/// the videos use: m4a assets and content:// songs both play). The song
/// starts at its [MemoryMusic.startMs]; with a [partMs] only that part
/// plays, again and again (the user's chosen part, as long as the video).
/// One song at a time; [load] replaces it.
final class MemoryMusicPlayer {
  VideoPlayerController? _controller;
  MemoryMusic? _music;
  Duration _start = Duration.zero;
  Duration? _end;
  bool _playing = false;
  bool _disposed = false;

  /// Plays [music] from its start ([NoMusic] = silence). Same music again =
  /// nothing changes. false = it could not be played (e.g. the picked song
  /// was deleted).
  Future<bool> load(
    MemoryMusic music, {
    required bool play,
    Duration? partMs,
  }) async {
    if (music == _music && _controller != null) return true;
    _music = music;
    await _release();
    if (music is NoMusic || _disposed) return true;
    final controller = switch (music) {
      BundledMusic(:final track) => VideoPlayerController.asset(track.asset),
      OwnMusic(:final uri) => VideoPlayerController.contentUri(Uri.parse(uri)),
      NoMusic() => null,
    };
    if (controller == null) return true;
    _controller = controller;
    _start = Duration(milliseconds: music.startMs);
    _end = partMs == null ? null : _start + partMs;
    try {
      await controller.initialize();
      if (_disposed || _controller != controller) {
        await controller.dispose();
        return true;
      }
      // A part shorter than the song: back to its start at its end (read
      // each time: the part can move).
      controller.addListener(() {
        final end = _end;
        if (end != null &&
            end < controller.value.duration &&
            controller.value.position >= end) {
          unawaited(controller.seekTo(_start));
        }
      });
      await controller.setLooping(true);
      if (_start > Duration.zero) await controller.seekTo(_start);
      if (play) await this.play();
      return true;
    } on Object catch (error, stackTrace) {
      AppLogger.e('Memory music failed', error: error, stackTrace: stackTrace);
      if (_controller == controller) _controller = null;
      await controller.dispose();
      return false;
    }
  }

  Future<void> play() async {
    _playing = true;
    await _controller?.play();
  }

  Future<void> pause() async {
    _playing = false;
    await _controller?.pause();
  }

  /// Back to the song's start (the show starts again).
  Future<void> restart() async {
    await _controller?.seekTo(_start);
    if (_playing) await _controller?.play();
  }

  /// The chosen part's start moved (the "choose a part" page).
  Future<void> moveStart(Duration start) async {
    final length = (_end ?? Duration.zero) - _start;
    _start = start;
    if (_end != null) _end = start + length;
    await _controller?.seekTo(start);
  }

  /// Where the song is now.
  Duration get position => _controller?.value.position ?? Duration.zero;

  Future<void> _release() async {
    final old = _controller;
    _controller = null;
    if (old != null) await old.dispose();
  }

  Future<void> dispose() async {
    _disposed = true;
    await _release();
  }
}
