import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:proalbums/features/gallery/presentation/providers/media_scope.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

export 'package:proalbums/features/gallery/presentation/providers/media_scope.dart';

part 'media_selection.g.dart';

/// How many of a group of photos are selected (for the date checkboxes).
enum SelectionState { none, partial, all }

/// Multi-select state of ONE screen's grid (see [MediaScope]).
@immutable
final class MediaSelection {
  const MediaSelection({this.active = false, this.ids = const <String>{}});

  /// Selection mode is on (checkmarks visible, taps select).
  /// It stays on even when nothing is selected, like the reference gallery.
  final bool active;

  /// Selected media ids, in the order they were selected.
  final Set<String> ids;

  int get count => ids.length;

  SelectionState stateOf(List<String> group) {
    if (group.isEmpty) return SelectionState.none;
    var selected = 0;
    for (final id in group) {
      if (ids.contains(id)) selected++;
    }
    if (selected == 0) return SelectionState.none;
    return selected == group.length ? SelectionState.all : SelectionState.partial;
  }

  @override
  bool operator ==(Object other) =>
      other is MediaSelection &&
      other.active == active &&
      setEquals(other.ids, ids);

  @override
  int get hashCode => Object.hash(active, Object.hashAllUnordered(ids));
}

/// The selection of one screen, by its [scope] (see [MediaScope]):
/// every screen has its OWN selection, so opening an album (or a picker)
/// never touches the Photos tab's selection. It is dropped by itself when
/// the screen closes (nothing watches it any more).
@riverpod
class MediaSelectionController extends _$MediaSelectionController {
  @override
  MediaSelection build(String scope) => const MediaSelection();

  /// The select icon in the app bar.
  void start() => state = const MediaSelection(active: true);

  void exit() => state = const MediaSelection();

  /// Leaves selection mode if this screen is still open (callers that
  /// awaited a dialog or another page: the screen may be gone by then).
  void exitIfOpen() {
    if (ref.mounted) exit();
  }

  /// Long press on a photo: starts selection mode AND selects it.
  void startWith(String id) {
    if (state.active) return toggle(id);
    state = MediaSelection(active: true, ids: {id});
  }

  void toggle(String id) {
    if (!state.active) return;
    final next = <String>{...state.ids};
    if (!next.remove(id)) next.add(id);
    state = MediaSelection(active: true, ids: next);
  }

  /// Date checkbox: everything selected -> unselect the day, otherwise select
  /// the whole day.
  void toggleGroup(List<String> group) {
    if (!state.active || group.isEmpty) return;
    final allSelected = state.stateOf(group) == SelectionState.all;
    final next = <String>{...state.ids};
    if (allSelected) {
      next.removeAll(group);
    } else {
      next.addAll(group);
    }
    state = MediaSelection(active: true, ids: next);
  }

  /// Used by drag-select: replaces the selection (and starts selection mode).
  void setIds(Set<String> ids) =>
      state = MediaSelection(active: true, ids: ids);

  void selectAll(Iterable<String> ids) =>
      state = MediaSelection(active: true, ids: {...ids});

  void clearSelection() => state = const MediaSelection(active: true);
}

/// Shortcut: the selection provider of the screen [context] is in.
MediaSelectionControllerProvider mediaSelectionOf(BuildContext context) =>
    mediaSelectionControllerProvider(MediaScope.of(context).id);
