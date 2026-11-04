import 'dart:math' as math;
import 'dart:ui';

/// A collage layout is a tree of splits: a cell holds one picture (its
/// [CollageCell.slot]), a split cuts its space in two along an axis at a
/// ratio. Dragging the line between two cells only changes one ratio.
sealed class CollageNode {
  const CollageNode();
}

final class CollageCell extends CollageNode {
  const CollageCell(this.slot);

  /// Which picture (0 = the first chosen) sits here.
  final int slot;
}

final class CollageSplit extends CollageNode {
  const CollageSplit({
    required this.sideBySide,
    required this.ratio,
    required this.first,
    required this.second,
  });

  /// true: [first] left, [second] right (a vertical line between them);
  /// false: [first] above, [second] below.
  final bool sideBySide;

  /// How much of the space [first] gets (0–1).
  final double ratio;
  final CollageNode first;
  final CollageNode second;

  CollageSplit withRatio(double value) => CollageSplit(
    sideBySide: sideBySide,
    ratio: value,
    first: first,
    second: second,
  );
}

/// A movable line of a layout: where it is, and the split it belongs to
/// ([path]: 0 = first child, 1 = second, from the root).
typedef CollageDivider = ({List<int> path, Rect rect, bool sideBySide});

/// The smallest share a cell can be dragged down to.
const double minCollageRatio = 0.15;

/// Each picture's place, in 0–1 coordinates of the collage.
Map<int, Rect> collageCellRects(CollageNode node, [Rect area = _unit]) {
  final rects = <int, Rect>{};
  void walk(CollageNode node, Rect area) {
    switch (node) {
      case CollageCell(:final slot):
        rects[slot] = area;
      case CollageSplit(
        :final sideBySide,
        :final ratio,
        :final first,
        :final second,
      ):
        final (a, b) = _cut(area, sideBySide, ratio);
        walk(first, a);
        walk(second, b);
    }
  }

  walk(node, area);
  return rects;
}

/// Every line between cells, in 0–1 coordinates.
List<CollageDivider> collageDividers(CollageNode node) {
  final lines = <CollageDivider>[];
  void walk(CollageNode node, Rect area, List<int> path) {
    if (node is! CollageSplit) return;
    final (a, b) = _cut(area, node.sideBySide, node.ratio);
    lines.add((
      path: path,
      rect: node.sideBySide
          ? Rect.fromLTRB(a.right, area.top, a.right, area.bottom)
          : Rect.fromLTRB(area.left, a.bottom, area.right, a.bottom),
      sideBySide: node.sideBySide,
    ));
    walk(node.first, a, [...path, 0]);
    walk(node.second, b, [...path, 1]);
  }

  walk(node, _unit, const []);
  return lines;
}

/// The same tree with the split at [path] moved by [delta] (a share of that
/// split's own space), kept between [minCollageRatio] and its mirror.
CollageNode moveCollageDivider(CollageNode node, List<int> path, double delta) {
  if (node is! CollageSplit) return node;
  if (path.isEmpty) {
    return node.withRatio(
      (node.ratio + delta).clamp(minCollageRatio, 1 - minCollageRatio),
    );
  }
  final rest = path.sublist(1);
  return CollageSplit(
    sideBySide: node.sideBySide,
    ratio: node.ratio,
    first: path.first == 0
        ? moveCollageDivider(node.first, rest, delta)
        : node.first,
    second: path.first == 1
        ? moveCollageDivider(node.second, rest, delta)
        : node.second,
  );
}

/// The size (0–1) of the area the split at [path] cuts, along its axis: a
/// finger moving d (in 0–1 of the collage) changes its ratio by d / this.
double collageSplitSpan(CollageNode node, List<int> path) {
  var area = _unit;
  var current = node;
  for (final step in path) {
    if (current is! CollageSplit) break;
    final (a, b) = _cut(area, current.sideBySide, current.ratio);
    area = step == 0 ? a : b;
    current = step == 0 ? current.first : current.second;
  }
  if (current is! CollageSplit) return 1;
  return current.sideBySide ? area.width : area.height;
}

/// The layouts offered for [count] pictures (2–9): pictures in rows, or in
/// columns, in several mixes (e.g. 5 = 2 + 3, 3 + 2, 1 + 4…), plus one long
/// strip each way for up to 4 pictures. The first one is the most even.
List<CollageNode> collageLayoutsFor(int count) {
  if (count < 2) return const [];
  final seen = <String>{};
  final layouts = <CollageNode>[];
  void add(CollageNode node) {
    if (seen.add(_signature(node))) layouts.add(node);
  }

  for (final parts in _patternsFor(count)) {
    add(_lines(parts, rowsOfPictures: true));
    add(_lines(parts, rowsOfPictures: false));
  }
  if (count <= 4) {
    add(_strip(List.generate(count, (i) => i), sideBySide: true));
    add(_strip(List.generate(count, (i) => i), sideBySide: false));
  }
  return layouts;
}

/// How [count] pictures can be put in 2–4 lines of 1–4 each, most even first,
/// at most 8 mixes.
List<List<int>> _patternsFor(int count) {
  final all = <List<int>>[];
  void build(List<int> prefix, int left) {
    if (left == 0) {
      if (prefix.length >= 2 && prefix.length <= 4) all.add(prefix);
      return;
    }
    if (prefix.length == 4) return;
    for (var part = 1; part <= math.min(4, left); part++) {
      build([...prefix, part], left - part);
    }
  }

  build(const [], count);
  double spread(List<int> parts) {
    final mean = count / parts.length;
    return parts.fold<double>(0, (sum, p) => sum + (p - mean) * (p - mean)) +
        (parts.length - 2.5).abs() * 0.5;
  }

  all.sort((a, b) => spread(a).compareTo(spread(b)));
  return all.take(8).toList();
}

/// Lines of pictures: [parts][i] pictures in line i. Rows (stacked) of
/// pictures side by side, or columns (side by side) of stacked pictures.
CollageNode _lines(List<int> parts, {required bool rowsOfPictures}) {
  var slot = 0;
  final lines = <CollageNode>[];
  for (final size in parts) {
    lines.add(
      _strip(List.generate(size, (i) => slot + i), sideBySide: rowsOfPictures),
    );
    slot += size;
  }
  return _even(lines, sideBySide: !rowsOfPictures);
}

/// Pictures [slots] in one strip, equal shares.
CollageNode _strip(List<int> slots, {required bool sideBySide}) => _even([
  for (final slot in slots) CollageCell(slot),
], sideBySide: sideBySide);

/// [nodes] in equal shares along one axis.
CollageNode _even(List<CollageNode> nodes, {required bool sideBySide}) {
  if (nodes.length == 1) return nodes.single;
  return CollageSplit(
    sideBySide: sideBySide,
    ratio: 1 / nodes.length,
    first: nodes.first,
    second: _even(nodes.sublist(1), sideBySide: sideBySide),
  );
}

String _signature(CollageNode node) => switch (node) {
  CollageCell(:final slot) => '$slot',
  CollageSplit(:final sideBySide, :final ratio, :final first, :final second) =>
    '(${sideBySide ? 'h' : 'v'}${ratio.toStringAsFixed(3)}'
        '${_signature(first)},${_signature(second)})',
};

(Rect, Rect) _cut(Rect area, bool sideBySide, double ratio) {
  if (sideBySide) {
    final x = area.left + area.width * ratio;
    return (
      Rect.fromLTRB(area.left, area.top, x, area.bottom),
      Rect.fromLTRB(x, area.top, area.right, area.bottom),
    );
  }
  final y = area.top + area.height * ratio;
  return (
    Rect.fromLTRB(area.left, area.top, area.right, y),
    Rect.fromLTRB(area.left, y, area.right, area.bottom),
  );
}

const Rect _unit = Rect.fromLTRB(0, 0, 1, 1);
