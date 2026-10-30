import 'dart:math' as math;

/// Drag-select: the photos between where the finger started ([anchor]) and
/// where it is now ([current]) are all selected (or all unselected).
///
/// Always computed from [base] (the selection before the drag), so moving the
/// finger back shrinks the range again, like the system gallery.
Set<String> dragSelection({
  required Set<String> base,
  required List<String> Function(int from, int to) idsBetween,
  required int anchor,
  required int current,
  required bool select,
}) {
  final range = idsBetween(math.min(anchor, current), math.max(anchor, current));
  final next = <String>{...base};
  if (select) {
    next.addAll(range);
  } else {
    next.removeAll(range);
  }
  return next;
}
