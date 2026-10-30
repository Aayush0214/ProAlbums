import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/features/gallery/presentation/providers/drag_selection.dart';

void main() {
  final all = ['0', '1', '2', '3', '4', '5', '6'];
  List<String> between(int from, int to) => all.sublist(from, to + 1);

  Set<String> run({
    Set<String> base = const {},
    required int anchor,
    required int current,
    bool select = true,
  }) =>
      dragSelection(
        base: base,
        idsBetween: between,
        anchor: anchor,
        current: current,
        select: select,
      );

  test('sliding down selects everything from the start to the finger', () {
    expect(run(anchor: 2, current: 4), {'2', '3', '4'});
  });

  test('sliding up works the same way', () {
    expect(run(anchor: 4, current: 2), {'2', '3', '4'});
  });

  test('moving the finger back shrinks the range', () {
    expect(run(anchor: 2, current: 5), {'2', '3', '4', '5'});
    expect(run(anchor: 2, current: 3), {'2', '3'});
  });

  test('photos selected before the drag stay selected', () {
    expect(run(base: {'0'}, anchor: 3, current: 4), {'0', '3', '4'});
  });

  test('starting on a selected photo UNselects the range', () {
    expect(
      run(base: {'1', '2', '3', '4'}, anchor: 2, current: 3, select: false),
      {'1', '4'},
    );
  });

  test('a single photo (no movement)', () {
    expect(run(anchor: 3, current: 3), {'3'});
  });
}
