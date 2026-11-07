import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/memories/data/memory_platform.dart';
import 'package:proalbums/features/memories/domain/memory_music.dart';
import 'package:proalbums/features/memories/presentation/memory_music_player.dart';
import 'package:proalbums/features/memories/presentation/memory_providers.dart';

/// What the "choose a part" page needs: the picked song and the video's
/// length.
typedef MusicTrimRequest = ({String uri, String name, int videoMs});

/// "Choose a part" (WhatsApp-like): the picked song's loudness as bars and
/// a window as long as the video on it; drag the window along the song,
/// the part plays (again and again) so the user hears it; ✓ = that part.
/// Pops with the part's start (ms), or null (X / Back).
class MemoryMusicTrimPage extends ConsumerStatefulWidget {
  const MemoryMusicTrimPage({required this.request, super.key});

  final MusicTrimRequest request;

  @override
  ConsumerState<MemoryMusicTrimPage> createState() =>
      _MemoryMusicTrimPageState();
}

class _MemoryMusicTrimPageState extends ConsumerState<MemoryMusicTrimPage> {
  final MemoryMusicPlayer _player = MemoryMusicPlayer();
  SongWave? _wave;
  bool _failed = false;
  int _startMs = 0;
  bool _playing = true;
  Timer? _tick;

  int get _videoMs => widget.request.videoMs;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    // The play line moves with the song.
    _tick = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted && _playing) setState(() {});
    });
  }

  Future<void> _load() async {
    final r = widget.request;
    // The song plays at once; the bars come when they are read.
    final playing = _player.load(
      OwnMusic(r.uri, r.name),
      play: true,
      partMs: Duration(milliseconds: _videoMs),
    );
    final wave = await ref.read(memoryPlatformProvider).waveform(r.uri);
    if (!mounted) return;
    setState(() {
      _wave = wave;
      _failed = wave == null;
    });
    if (!await playing && mounted) setState(() => _failed = true);
  }

  @override
  void dispose() {
    _tick?.cancel();
    unawaited(_player.dispose());
    super.dispose();
  }

  void _drag(double dx, double width, int songMs) {
    final next = clampMusicStart(
      startMs: _startMs + (dx / width * songMs).round(),
      songMs: songMs,
      videoMs: _videoMs,
    );
    if (next != _startMs) setState(() => _startMs = next);
  }

  Future<void> _dragEnd() async {
    await _player.moveStart(Duration(milliseconds: _startMs));
    if (_playing) await _player.play();
  }

  Future<void> _playPause() async {
    setState(() => _playing = !_playing);
    _playing ? await _player.play() : await _player.pause();
  }

  String _clock(int ms) {
    final s = ms ~/ 1000;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:'
        '${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    const white = AppColors.mediaBadgeText;
    final secondary = white.withValues(alpha: 0.6);
    final wave = _wave;
    final songMs = wave?.durationMs ?? 0;
    final shorter = wave != null && songMs <= _videoMs;
    final endMs = shorter ? songMs : _startMs + _videoMs;

    return Scaffold(
      backgroundColor: AppColors.darkCanvasObsidian,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Cancel',
                    icon: const Icon(LucideIcons.x, color: white),
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: Text(
                      'Choose a part',
                      textAlign: TextAlign.center,
                      style: context.textTheme.titleLarge?.copyWith(
                        color: white,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Done',
                    icon: const Icon(LucideIcons.check, color: white),
                    onPressed: () => context.pop(_startMs),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Icon(LucideIcons.music, size: 40, color: secondary),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                widget.request.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: context.textTheme.titleMedium?.copyWith(color: white),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              shorter
                  ? 'The song is shorter than the video: it repeats'
                  : 'Drag to choose ${_clock(_videoMs)} of the song',
              style: context.textTheme.bodySmall?.copyWith(color: secondary),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 96,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: wave == null
                    ? Center(
                        child: _failed
                            ? Text(
                                'This song cannot be read',
                                style: context.textTheme.bodyMedium?.copyWith(
                                  color: secondary,
                                ),
                              )
                            : CircularProgressIndicator(
                                color: context.colorScheme.primary,
                              ),
                      )
                    : LayoutBuilder(
                        builder: (context, box) => GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragUpdate: shorter
                              ? null
                              : (d) => _drag(d.delta.dx, box.maxWidth, songMs),
                          onHorizontalDragEnd: shorter
                              ? null
                              : (_) => unawaited(_dragEnd()),
                          child: CustomPaint(
                            size: Size(box.maxWidth, 96),
                            painter: _WavePainter(
                              bars: wave.bars,
                              from: songMs == 0 ? 0 : _startMs / songMs,
                              to: songMs == 0 ? 1 : endMs / songMs,
                              playAt: songMs == 0
                                  ? null
                                  : _player.position.inMilliseconds / songMs,
                              bar: white,
                              dim: white.withValues(alpha: 0.25),
                              frame: context.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            if (wave != null)
              Text(
                '${_clock(_startMs)}  –  ${_clock(endMs)}',
                style: context.textTheme.titleMedium?.copyWith(
                  color: white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            const SizedBox(height: 24),
            IconButton(
              tooltip: _playing ? 'Pause' : 'Play',
              iconSize: 36,
              onPressed: _failed ? null : () => unawaited(_playPause()),
              icon: Icon(
                _playing ? LucideIcons.pause : LucideIcons.play,
                color: white,
              ),
            ),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}

/// The song's bars; the chosen part [from]–[to] (0–1) is bright inside a
/// rounded frame, the rest dim; [playAt] = the play line.
class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.bars,
    required this.from,
    required this.to,
    required this.playAt,
    required this.bar,
    required this.dim,
    required this.frame,
  });

  final List<double> bars;
  final double from;
  final double to;
  final double? playAt;
  final Color bar;
  final Color dim;
  final Color frame;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    final step = size.width / bars.length;
    final paint = Paint()..strokeCap = StrokeCap.round;
    paint.strokeWidth = (step * 0.6).clamp(1.0, 4.0);
    for (var i = 0; i < bars.length; i++) {
      final x = step * (i + 0.5);
      final t = x / size.width;
      final h = (0.12 + 0.88 * bars[i]) * size.height * 0.8;
      paint.color = t >= from && t <= to ? bar : dim;
      canvas.drawLine(
        Offset(x, (size.height - h) / 2),
        Offset(x, (size.height + h) / 2),
        paint,
      );
    }
    final window = RRect.fromRectAndRadius(
      Rect.fromLTRB(from * size.width, 0, to * size.width, size.height),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      window,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = frame,
    );
    final play = playAt;
    if (play != null && play >= from && play <= to) {
      final x = play * size.width;
      canvas.drawLine(
        Offset(x, 4),
        Offset(x, size.height - 4),
        Paint()
          ..strokeWidth = 2
          ..color = frame,
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.from != from ||
      old.to != to ||
      old.playAt != playAt ||
      old.bars != bars;
}
