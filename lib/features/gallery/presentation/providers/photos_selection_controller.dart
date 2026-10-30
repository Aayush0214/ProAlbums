import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'photos_selection_controller.g.dart';

/// Multi-select state of the Photos tab.
/// How many of a group of photos are selected (for the date checkboxes).
enum SelectionState { none, partial, all }

@immutable
final class PhotosSelection {
  const PhotosSelection({this.active = false, this.ids = const <String>{}});

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
      other is PhotosSelection &&
      other.active == active &&
      setEquals(other.ids, ids);

  @override
  int get hashCode => Object.hash(active, Object.hashAllUnordered(ids));
}

@Riverpod(keepAlive: true)
class PhotosSelectionController extends _$PhotosSelectionController {
  @override
  PhotosSelection build() => const PhotosSelection();

  /// The select icon in the app bar.
  void start() => state = const PhotosSelection(active: true);

  void exit() => state = const PhotosSelection();

  /// Long press on a photo: starts selection mode AND selects it.
  void startWith(String id) {
    if (state.active) return toggle(id);
    state = PhotosSelection(active: true, ids: {id});
  }

  void toggle(String id) {
    if (!state.active) return;
    final next = <String>{...state.ids};
    if (!next.remove(id)) next.add(id);
    state = PhotosSelection(active: true, ids: next);
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
    state = PhotosSelection(active: true, ids: next);
  }

  /// Used by drag-select: replaces the selection (and starts selection mode).
  void setIds(Set<String> ids) =>
      state = PhotosSelection(active: true, ids: ids);

  void selectAll(Iterable<String> ids) =>
      state = PhotosSelection(active: true, ids: {...ids});

  void clearSelection() => state = const PhotosSelection(active: true);
}
