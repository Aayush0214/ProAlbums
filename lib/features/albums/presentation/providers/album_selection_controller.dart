import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'album_selection_controller.g.dart';

@immutable
final class AlbumSelectionState {
  const AlbumSelectionState({this.active = false, this.ids = const {}});

  /// Select mode is on (checkboxes, "N selected", the bottom bar).
  final bool active;
  final Set<String> ids;

  int get count => ids.length;
}

/// Select mode of ONE albums screen. [scope] tells the screens apart:
/// 'albums' (the tab) and 'other' (Other albums).
@riverpod
class AlbumSelection extends _$AlbumSelection {
  @override
  AlbumSelectionState build(String scope) => const AlbumSelectionState();

  void start() => state = const AlbumSelectionState(active: true);

  /// Long press on an album: select mode starts with that album selected.
  void startWith(String id) =>
      state = AlbumSelectionState(active: true, ids: {id});

  void toggle(String id) {
    final ids = {...state.ids};
    if (!ids.remove(id)) ids.add(id);
    state = AlbumSelectionState(active: true, ids: ids);
  }

  void selectAll(Iterable<String> all) =>
      state = AlbumSelectionState(active: true, ids: all.toSet());

  void clear() => state = const AlbumSelectionState(active: true);

  void exit() => state = const AlbumSelectionState();
}
