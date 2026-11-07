import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/features/memories/domain/memory_music.dart';
import 'package:proalbums/features/memories/domain/memory_rules.dart';

void main() {
  test('stored text round-trips', () {
    for (final music in [
      const NoMusic(),
      const BundledMusic(BundledTrack.somewhereNice),
      const OwnMusic('content://media/audio/7', 'Song'),
    ]) {
      expect(MemoryMusic.parse(music.stored, name: 'Song'), music);
    }
    expect(MemoryMusic.parse(null), isNull);
    expect(MemoryMusic.parse('track:gone'), isNull);
  });

  test('every kind has a song of the app', () {
    for (final kind in MemoryKind.values) {
      expect(musicOf(kind, null), isA<BundledMusic>());
    }
    expect(musicOf(MemoryKind.trip, const NoMusic()), const NoMusic());
  });

  test('where the video maker reads the music', () {
    expect(
      musicSource(const BundledMusic(BundledTrack.rustyBicycle)),
      'asset:///flutter_assets/assets/musics/rusty_bicycle.m4a',
    );
    expect(musicSource(const OwnMusic('content://a/1', 'x')), 'content://a/1');
    expect(musicSource(const NoMusic()), isNull);
  });

  test('the part of a song stays inside it', () {
    // 2-minute song, 30 s video.
    expect(
      clampMusicStart(startMs: 50000, songMs: 120000, videoMs: 30000),
      50000,
    );
    expect(
      clampMusicStart(startMs: 110000, songMs: 120000, videoMs: 30000),
      90000,
    );
    expect(clampMusicStart(startMs: -5, songMs: 120000, videoMs: 30000), 0);
    // A song shorter than the video: from 0 (it loops).
    expect(clampMusicStart(startMs: 9000, songMs: 20000, videoMs: 30000), 0);
  });

  test('the start of the own song is remembered', () {
    expect(
      MemoryMusic.parse(
        'uri:content://a/1',
        name: 'x',
        startMs: 42000,
      )!.startMs,
      42000,
    );
  });
}
