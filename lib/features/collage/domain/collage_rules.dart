import 'dart:ui';

/// Collage limits and the meaning of the sliders.
abstract final class CollageRules {
  static const int minPictures = 2;
  static const int maxPictures = 9;

  /// Rounded corner / Margin / Padding sliders go 0–100; a step is this share
  /// of the collage's width (30 → 3 %).
  static const double unitOfWidth = 0.001;

  static const double defaultMargin = 30;
  static const double defaultPadding = 30;
  static const double defaultCorner = 0;

  /// Album (folder) the collages are saved in: Pictures/Collage.
  static const String folder = 'Pictures/Collage/';

  /// The saved collage's long side in pixels.
  static const int exportLongEdge = 3000;

  /// Pictures are read this big for the collage (more pictures = smaller
  /// cells = smaller pictures needed, and less memory).
  static int pictureSizeFor(int count) => count <= 2
      ? 2048
      : count <= 4
      ? 1600
      : 1200;
}

/// The Ratio tab.
enum CollageRatio {
  square('1:1', 1),
  fourThree('4:3', 4 / 3),
  threeFour('3:4', 3 / 4),
  sixteenNine('16:9', 16 / 9),
  nineSixteen('9:16', 9 / 16);

  const CollageRatio(this.label, this.value);

  final String label;

  /// width / height
  final double value;
}

/// The background colours (white is the first, like the system gallery).
const List<Color> collageBackgrounds = [
  Color(0xFFFFFFFF),
  Color(0xFF2B2B2B),
  Color(0xFF9E9E9E),
  Color(0xFFF2A7B1),
  Color(0xFFFFD3A5),
  Color(0xFFA8D8A8),
  Color(0xFF9CC5DE),
  Color(0xFFDDB7DD),
];

/// Simple colour filters (a colour matrix each: cheap live and when saving).
enum CollageFilter {
  original('Original', null),
  vivid('Vivid', [
    1.25, -0.15, -0.1, 0, 0, //
    -0.1, 1.25, -0.15, 0, 0,
    -0.1, -0.15, 1.25, 0, 0,
    0, 0, 0, 1, 0,
  ]),
  warm('Warm', [
    1.1, 0, 0, 0, 12, //
    0, 1.02, 0, 0, 4,
    0, 0, 0.88, 0, -6,
    0, 0, 0, 1, 0,
  ]),
  cool('Cool', [
    0.9, 0, 0, 0, -6, //
    0, 1.0, 0, 0, 2,
    0, 0, 1.12, 0, 12,
    0, 0, 0, 1, 0,
  ]),
  fade('Fade', [
    0.82, 0.05, 0.05, 0, 28, //
    0.05, 0.82, 0.05, 0, 28,
    0.05, 0.05, 0.82, 0, 28,
    0, 0, 0, 1, 0,
  ]),
  vintage('Vintage', [
    0.9, 0.2, 0.05, 0, 10, //
    0.1, 0.8, 0.1, 0, 6,
    0.05, 0.1, 0.65, 0, 0,
    0, 0, 0, 1, 0,
  ]),
  sepia('Sepia', [
    0.393, 0.769, 0.189, 0, 0, //
    0.349, 0.686, 0.168, 0, 0,
    0.272, 0.534, 0.131, 0, 0,
    0, 0, 0, 1, 0,
  ]),
  mono('B/W', [
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ]),
  noir('Noir', [
    0.32, 1.07, 0.11, 0, -48, //
    0.32, 1.07, 0.11, 0, -48,
    0.32, 1.07, 0.11, 0, -48,
    0, 0, 0, 1, 0,
  ]);

  const CollageFilter(this.label, this.matrix);

  final String label;

  /// 4×5 colour matrix (Flutter's ColorFilter.matrix); null = unchanged.
  final List<double>? matrix;
}

/// One picture's own settings in a cell: turned, mirrored, filtered, and
/// how it is zoomed / moved inside its cell (scale ≥ 1 = at least covering
/// the cell; offset in cell sizes, kept so the cell is always covered).
final class CollagePicture {
  const CollagePicture({
    this.quarterTurns = 0,
    this.mirrorX = false,
    this.mirrorY = false,
    this.filter = CollageFilter.original,
    this.scale = 1,
    this.offset = Offset.zero,
  });

  final int quarterTurns;
  final bool mirrorX;
  final bool mirrorY;
  final CollageFilter filter;
  final double scale;
  final Offset offset;

  CollagePicture copyWith({
    int? quarterTurns,
    bool? mirrorX,
    bool? mirrorY,
    CollageFilter? filter,
    double? scale,
    Offset? offset,
  }) => CollagePicture(
    quarterTurns: quarterTurns ?? this.quarterTurns,
    mirrorX: mirrorX ?? this.mirrorX,
    mirrorY: mirrorY ?? this.mirrorY,
    filter: filter ?? this.filter,
    scale: scale ?? this.scale,
    offset: offset ?? this.offset,
  );
}

/// A picture on the Free layout: its centre (0–1 of the collage), width
/// (share of the collage's width) and turn (radians). Later ones are on top.
final class FreePicture {
  const FreePicture({
    required this.slot,
    required this.center,
    required this.width,
    this.angle = 0,
  });

  final int slot;
  final Offset center;
  final double width;
  final double angle;

  FreePicture copyWith({Offset? center, double? width, double? angle}) =>
      FreePicture(
        slot: slot,
        center: center ?? this.center,
        width: width ?? this.width,
        angle: angle ?? this.angle,
      );
}

/// Where the pictures start on the Free layout: a loose cascade, each a bit
/// turned, so they can be seen and picked up.
List<FreePicture> freeStartFor(int count) {
  const angles = [-0.08, 0.06, -0.04, 0.09, -0.07, 0.05, -0.1, 0.03, 0.07];
  final columns = count <= 4 ? 2 : 3;
  final rows = (count / columns).ceil();
  return [
    for (var i = 0; i < count; i++)
      FreePicture(
        slot: i,
        center: Offset(
          (i % columns + 0.5) / columns,
          ((i ~/ columns) + 0.5) / rows,
        ),
        width: 0.9 / columns,
        angle: angles[i % angles.length],
      ),
  ];
}

/// Collage enabled? Only pictures, 2 or more (more than 9 → a message when
/// it is pressed).
bool canMakeCollage({required int count, required bool hasVideo}) =>
    count >= CollageRules.minPictures && !hasVideo;
