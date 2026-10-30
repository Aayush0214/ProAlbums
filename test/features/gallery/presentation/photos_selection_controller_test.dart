import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/features/gallery/presentation/providers/photos_selection_controller.dart';

void main() {
  groupSelectionTests();

  late ProviderContainer container;
  PhotosSelection state() => container.read(photosSelectionControllerProvider);
  PhotosSelectionController notifier() =>
      container.read(photosSelectionControllerProvider.notifier);

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  test('starts off', () {
    expect(state().active, isFalse);
    expect(state().count, 0);
  });

  test('the select icon starts selection mode with nothing selected', () {
    notifier().start();
    expect(state().active, isTrue);
    expect(state().count, 0);
  });

  test('a long press starts selection and selects that photo', () {
    notifier().startWith('7');
    expect(state().active, isTrue);
    expect(state().ids, {'7'});
  });

  test('a tap toggles a photo while selecting', () {
    notifier()
      ..startWith('1')
      ..toggle('2');
    expect(state().ids, {'1', '2'});

    notifier().toggle('1');
    expect(state().ids, {'2'});
  });

  test('tapping does nothing when selection mode is off', () {
    notifier().toggle('1');
    expect(state().active, isFalse);
    expect(state().ids, isEmpty);
  });

  test('deselecting the last photo keeps selection mode on', () {
    notifier()
      ..startWith('1')
      ..toggle('1');
    expect(state().active, isTrue);
    expect(state().count, 0);
  });

  test('select all, clear and exit', () {
    notifier().selectAll(['1', '2', '3']);
    expect(state().count, 3);

    notifier().clearSelection();
    expect(state().active, isTrue);
    expect(state().count, 0);

    notifier().exit();
    expect(state().active, isFalse);
  });
}

void groupSelectionTests() {
  group('selecting a whole day', () {
    late ProviderContainer container;
    PhotosSelection state() => container.read(photosSelectionControllerProvider);
    PhotosSelectionController notifier() =>
        container.read(photosSelectionControllerProvider.notifier);
    const day = ['a', 'b', 'c'];

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    test('the day checkbox selects every photo of that day', () {
      notifier()
        ..start()
        ..toggleGroup(day);
      expect(state().ids, {'a', 'b', 'c'});
      expect(state().stateOf(day), SelectionState.all);
    });

    test('a half selected day shows partial, and the next tap completes it', () {
      notifier()
        ..startWith('a')
        ..toggle('b');
      expect(state().stateOf(day), SelectionState.partial);

      notifier().toggleGroup(day);
      expect(state().stateOf(day), SelectionState.all);
    });

    test('tapping a fully selected day unselects only that day', () {
      notifier()
        ..selectAll(['a', 'b', 'c', 'z'])
        ..toggleGroup(day);
      expect(state().ids, {'z'});
      expect(state().stateOf(day), SelectionState.none);
    });

    test('does nothing when selection mode is off', () {
      notifier().toggleGroup(day);
      expect(state().active, isFalse);
    });
  });
}
