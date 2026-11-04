import 'dart:math' as math;

/// One picture as Cleanup suggestions sees it.
final class CleanupImage {
  const CleanupImage({
    required this.id,
    required this.size,
    required this.width,
    required this.height,
    required this.takenMs,
    this.dhash,
    this.sharpness = 0,
    this.sha1,
  });

  final String id;

  /// Bytes.
  final int size;
  final int width;
  final int height;
  final int takenMs;

  /// Difference hash (null = not looked at yet).
  final int? dhash;
  final double sharpness;

  /// File hash (only for exact-duplicate candidates).
  final String? sha1;

  int get pixels => width * height;
}

/// The cards of Cleanup suggestions. More can be added: a card shows only
/// when it has something.
enum CleanupKind {
  duplicates('Duplicate images'),
  similar('Similar images');

  const CleanupKind(this.title);

  final String title;
}

/// A set of pictures that are the same (or nearly).
typedef CleanupGroup = List<CleanupImage>;

abstract final class CleanupRules {
  /// dHash bits that may differ for two pictures to count as similar.
  static const int similarBits = 10;

  /// Similar pictures are taken close together (burst, a few tries).
  static const Duration similarWindow = Duration(minutes: 10);

  /// And at most this many pictures apart (keeps the work small).
  static const int similarLookAhead = 40;

  /// Sharpness within this share of the best counts as equally sharp.
  static const double sameSharpness = 0.05;
}

/// Bits that differ between two 64-bit hashes.
int hammingDistance(int a, int b) {
  var x = a ^ b;
  var count = 0;
  while (x != 0) {
    x &= x - 1;
    count++;
  }
  return count;
}

/// Pictures that share size AND dimensions: the only ones whose file hash is
/// worth reading (an exact copy has the same bytes).
List<CleanupImage> duplicateCandidates(List<CleanupImage> images) {
  final bySignature = <String, List<CleanupImage>>{};
  for (final image in images) {
    bySignature
        .putIfAbsent('${image.size}:${image.width}x${image.height}', () => [])
        .add(image);
  }
  return [
    for (final group in bySignature.values)
      if (group.length > 1) ...group,
  ];
}

/// Exact copies: same file hash. Newest group first.
List<CleanupGroup> duplicateGroups(List<CleanupImage> images) {
  final bySha = <String, List<CleanupImage>>{};
  for (final image in duplicateCandidates(images)) {
    final sha = image.sha1;
    if (sha == null) continue;
    bySha.putIfAbsent(sha, () => []).add(image);
  }
  return _sorted([
    for (final group in bySha.values)
      if (group.length > 1) group,
  ]);
}

/// Near pictures: taken within [CleanupRules.similarWindow] of each other
/// with dHashes at most [CleanupRules.similarBits] apart, linked into sets.
/// Exact copies are left to [duplicateGroups].
List<CleanupGroup> similarGroups(List<CleanupImage> images) {
  final list = [
    for (final image in images)
      if (image.dhash != null) image,
  ]..sort((a, b) => a.takenMs.compareTo(b.takenMs));
  final parent = List<int>.generate(list.length, (i) => i);
  int find(int i) {
    var root = i;
    while (parent[root] != root) {
      root = parent[root];
    }
    while (parent[i] != root) {
      final next = parent[i];
      parent[i] = root;
      i = next;
    }
    return root;
  }

  final window = CleanupRules.similarWindow.inMilliseconds;
  for (var i = 0; i < list.length; i++) {
    final a = list[i];
    final last = math.min(list.length, i + 1 + CleanupRules.similarLookAhead);
    for (var j = i + 1; j < last; j++) {
      final b = list[j];
      if (b.takenMs - a.takenMs > window) break;
      final sameFile = a.sha1 != null && a.sha1 == b.sha1;
      if (sameFile) continue;
      if (hammingDistance(a.dhash!, b.dhash!) <= CleanupRules.similarBits) {
        parent[find(j)] = find(i);
      }
    }
  }
  final sets = <int, List<CleanupImage>>{};
  for (var i = 0; i < list.length; i++) {
    sets.putIfAbsent(find(i), () => []).add(list[i]);
  }
  return _sorted([
    for (final group in sets.values)
      if (group.length > 1) group,
  ]);
}

/// Newest set first; inside a set, oldest first (the order they were taken).
List<CleanupGroup> _sorted(List<CleanupGroup> groups) {
  for (final group in groups) {
    group.sort((a, b) => a.takenMs.compareTo(b.takenMs));
  }
  return groups..sort((a, b) => b.first.takenMs.compareTo(a.first.takenMs));
}

/// "Smart recommendation": the picture of a set to KEEP — the sharpest
/// (least blurred); when about as sharp, the one with more pixels, then the
/// bigger file.
CleanupImage bestOf(CleanupGroup group) {
  final sharpest = group.map((i) => i.sharpness).reduce(math.max);
  final candidates = [
    for (final image in group)
      if (sharpest == 0 ||
          image.sharpness >= sharpest * (1 - CleanupRules.sameSharpness))
        image,
  ];
  return candidates.reduce((best, image) {
    if (image.pixels != best.pixels) {
      return image.pixels > best.pixels ? image : best;
    }
    return image.size > best.size ? image : best;
  });
}

/// "2.40 MB", "446 KB", "721 MB" (1000 based, like the system gallery).
String cleanupSize(int bytes) {
  const kb = 1000;
  const mb = kb * 1000;
  const gb = mb * 1000;
  if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(2)} GB';
  if (bytes >= 100 * mb) return '${(bytes / mb).round()} MB';
  if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(2)} MB';
  return '${math.max(1, (bytes / kb).round())} KB';
}
