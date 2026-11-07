import 'package:proalbums/features/memories/domain/memory_rules.dart';

/// A song that comes with the app (all CC0, John Bartmann; see
/// assets/musics/LICENSES.md).
enum BundledTrack {
  rustyBicycle('Rusty Bicycle', 'assets/musics/rusty_bicycle.m4a'),
  poeticLoveLetter(
    'Poetic Love Letter',
    'assets/musics/poetic_love_letter.m4a',
  ),
  somewhereNice('Somewhere Nice', 'assets/musics/somewhere_nice.m4a'),
  oneNightInAfrica(
    'One Night In Africa',
    'assets/musics/one_night_in_africa.m4a',
  ),
  brightTenementSkyline(
    'Bright Tenement Skyline',
    'assets/musics/bright_tenement_skyline.m4a',
  );

  const BundledTrack(this.title, this.asset);

  final String title;
  final String asset;
}

/// A memory's music, as chosen (or the app's choice).
sealed class MemoryMusic {
  const MemoryMusic();

  /// What is stored (null = the app's choice, see [musicForKind]).
  String get stored;

  /// Shown name.
  String get title;

  /// Where the song starts (ms); only the user's own song can start later.
  int get startMs => 0;

  /// Stored text → music; null / unknown = null (the app's choice).
  static MemoryMusic? parse(String? stored, {String? name, int? startMs}) {
    if (stored == null) return null;
    if (stored == 'none') return const NoMusic();
    if (stored.startsWith('track:')) {
      final id = stored.substring('track:'.length);
      for (final track in BundledTrack.values) {
        if (track.name == id) return BundledMusic(track);
      }
      return null;
    }
    if (stored.startsWith('uri:')) {
      return OwnMusic(
        stored.substring('uri:'.length),
        name ?? 'My music',
        startMs: startMs ?? 0,
      );
    }
    return null;
  }
}

/// Silence.
final class NoMusic extends MemoryMusic {
  const NoMusic();

  @override
  String get stored => 'none';

  @override
  String get title => 'No music';

  @override
  bool operator ==(Object other) => other is NoMusic;

  @override
  int get hashCode => 0;
}

/// A song of the app.
final class BundledMusic extends MemoryMusic {
  const BundledMusic(this.track);

  final BundledTrack track;

  @override
  String get stored => 'track:${track.name}';

  @override
  String get title => track.title;

  @override
  bool operator ==(Object other) =>
      other is BundledMusic && other.track == track;

  @override
  int get hashCode => track.hashCode;
}

/// A song the user picked on the phone (a content:// address kept with a
/// lasting read permission), played from [startMs] (the part chosen,
/// WhatsApp-like, as long as the video).
final class OwnMusic extends MemoryMusic {
  const OwnMusic(this.uri, this.name, {this.startMs = 0});

  final String uri;
  final String name;

  @override
  final int startMs;

  @override
  String get stored => 'uri:$uri';

  @override
  String get title => name;

  @override
  bool operator ==(Object other) =>
      other is OwnMusic && other.uri == uri && other.startMs == startMs;

  @override
  int get hashCode => Object.hash(uri, startMs);
}

/// The part of a song a video of [videoMs] plays when the user puts its
/// start at [startMs]: kept inside the song (a song shorter than the video
/// plays from 0 and loops).
int clampMusicStart({
  required int startMs,
  required int songMs,
  required int videoMs,
}) {
  final last = songMs - videoMs;
  if (last <= 0) return 0;
  return startMs.clamp(0, last);
}

/// The app's song for a kind of memory (until the user picks one).
BundledTrack musicForKind(MemoryKind kind) => switch (kind) {
  MemoryKind.day || MemoryKind.weekend => BundledTrack.rustyBicycle,
  MemoryKind.trip => BundledTrack.oneNightInAfrica,
  MemoryKind.month => BundledTrack.somewhereNice,
  MemoryKind.person || MemoryKind.pastTimes => BundledTrack.poeticLoveLetter,
  MemoryKind.groupPhotos => BundledTrack.brightTenementSkyline,
};

/// What a memory plays: the user's choice, else the app's.
MemoryMusic musicOf(MemoryKind kind, MemoryMusic? chosen) =>
    chosen ?? BundledMusic(musicForKind(kind));

/// Where the video maker reads the music: the app's songs are inside the
/// APK under flutter_assets ("asset:///…"), the user's own song is its
/// content:// address; null = silent.
String? musicSource(MemoryMusic music) => switch (music) {
  BundledMusic(:final track) => 'asset:///flutter_assets/${track.asset}',
  OwnMusic(:final uri) => uri,
  NoMusic() => null,
};
