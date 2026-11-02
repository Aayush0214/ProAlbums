import 'package:flutter/foundation.dart';
import 'package:proalbums/core/storage/shared_preferences_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'album_prefs_controller.g.dart';

/// What the person decided about HOW the albums look (not what they contain).
@immutable
final class AlbumPrefs {
  const AlbumPrefs({this.others = const {}, this.covers = const {}});

  /// Albums sent to "Other albums" (album NAMES: the id of a folder changes
  /// when it is renamed, the person's choice must not be lost then).
  final Set<String> others;

  /// Album name -> id of the picture chosen as its cover.
  final Map<String, String> covers;
}

/// Saved on the phone (SharedPreferences), restored on the next start.
@Riverpod(keepAlive: true)
class AlbumPrefsController extends _$AlbumPrefsController {
  static const String _othersKey = 'albums_in_others_by_name';
  static const String _coversKey = 'album_covers_by_name';

  @override
  AlbumPrefs build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final covers = <String, String>{};
    for (final entry in prefs.getStringList(_coversKey) ?? const <String>[]) {
      final cut = entry.indexOf('|');
      if (cut > 0) covers[entry.substring(0, cut)] = entry.substring(cut + 1);
    }
    return AlbumPrefs(
      others: (prefs.getStringList(_othersKey) ?? const <String>[]).toSet(),
      covers: covers,
    );
  }

  void sendToOthers(Iterable<String> albumNames) =>
      _setOthers({...state.others, ...albumNames});

  void removeFromOthers(Iterable<String> albumNames) =>
      _setOthers(state.others.difference(albumNames.toSet()));

  /// The album got a new name: it keeps its place in "Other albums" and its
  /// cover.
  void renameAlbum(String from, String to) {
    if (state.others.contains(from)) {
      _setOthers({...state.others}..remove(from)..add(to));
    }
    final cover = state.covers[from];
    if (cover != null) {
      final covers = {...state.covers}..remove(from);
      _setCovers({...covers, to: cover});
    }
  }

  /// The albums were deleted: forget their place in Others and their cover.
  void forget(Iterable<String> albumNames) {
    final names = albumNames.toSet();
    _setOthers(state.others.difference(names));
    _setCovers({
      for (final e in state.covers.entries)
        if (!names.contains(e.key)) e.key: e.value,
    });
  }

  /// These albums lost their chosen cover (the picture is gone, or the album
  /// itself is gone): they show their newest picture again.
  void dropCovers(Iterable<String> albumNames) {
    final names = albumNames.toSet();
    if (!state.covers.keys.any(names.contains)) return;
    _setCovers({
      for (final e in state.covers.entries)
        if (!names.contains(e.key)) e.key: e.value,
    });
  }

  void setCover(String albumName, String mediaId) =>
      _setCovers({...state.covers, albumName: mediaId});

  void _setCovers(Map<String, String> covers) {
    state = AlbumPrefs(others: state.others, covers: covers);
    ref.read(sharedPreferencesProvider).setStringList(_coversKey, [
      for (final e in covers.entries) '${e.key}|${e.value}',
    ]);
  }

  void _setOthers(Set<String> others) {
    state = AlbumPrefs(others: others, covers: state.covers);
    ref.read(sharedPreferencesProvider).setStringList(
          _othersKey,
          others.toList(growable: false),
        );
  }
}
