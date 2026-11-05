import 'dart:math' as math;
import 'dart:typed_data';

/// Numbers for People (tuned on the phone; change here only).
abstract final class FaceRules {
  /// A face joins a known person when its average cosine to the person's
  /// faces is at least this (SFace's own same-person line for one pair is
  /// 0.363). Higher = fewer mix-ups, more split people (Merge fixes those).
  static const double samePerson = 0.40;

  /// A weak face (small: [strongSize]) joins only when this sure.
  static const double weakSamePerson = 0.48;

  /// New people come from groups of faces: two groups join while the
  /// AVERAGE cosine of all their face pairs is at least this (one
  /// look-alike face cannot join two people, see [averageGroups]).
  static const double joinGroups = 0.38;

  /// After grouping, a face whose score to its own person ([personScore])
  /// is below this goes back to nobody (it was most likely someone else).
  static const double minScoreInPerson = 0.32;

  /// A group needs at least this many faces to become a person, so one
  /// look-alike pair cannot.
  static const int minFacesForPerson = 3;

  /// [averageGroups] compares every pair, so it takes at most this many
  /// faces at once (the rest wait for the next grouping): ~36 MB.
  static const int maxFacesPerGrouping = 3000;

  /// Faces at least this wide (share of the picture's short side, ≈ 60 px
  /// in the scanned picture) are strong enough to start a new person.
  static const double strongSize = 0.08;

  /// Change when the grouping rules change: every face is grouped again
  /// (the faces themselves are kept; user changes are lost).
  static const int groupingVersion = 8;

  /// Change when FaceChannel finds or reads faces differently: every
  /// picture is looked at again (all faces and people are lost).
  static const int scanVersion = 2;

  /// Two people at least this close (but not [samePerson]) are offered as
  /// "Similar people have been detected. Merge now".
  static const double similarPeople = 0.30;

  /// The app puts a person on the People page when they are in at least
  /// this many pictures...
  static const int minPicturesShown = 5;

  /// ...and only the people with the most pictures, at most this many.
  static const int maxAutoShown = 20;

  /// Featured pictures on a person's page (and its slideshow).
  static const int maxFeatured = 20;

  /// The "+" page lists people in at least this many pictures (a face seen
  /// once is mostly a stranger in the background).
  static const int minPicturesToAdd = 2;

  /// Embedding length of SFace.
  static const int embeddingLength = 128;
}

/// float32 little-endian bytes (as stored / sent by FaceChannel) → numbers.
Float32List embeddingFromBytes(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  return Float32List.fromList([
    for (var i = 0; i + 4 <= bytes.length; i += 4)
      data.getFloat32(i, Endian.little),
  ]);
}

/// Numbers → float32 little-endian bytes.
Uint8List embeddingToBytes(Float32List vector) {
  final data = ByteData(vector.length * 4);
  for (var i = 0; i < vector.length; i++) {
    data.setFloat32(i * 4, vector[i], Endian.little);
  }
  return data.buffer.asUint8List();
}

double _dot(Float32List a, Float32List b) {
  var sum = 0.0;
  final n = math.min(a.length, b.length);
  for (var i = 0; i < n; i++) {
    sum += a[i] * b[i];
  }
  return sum;
}

/// Cosine of the angle between two embeddings (1 = same direction).
double faceCosine(Float32List a, Float32List b) {
  final length = math.sqrt(_dot(a, a) * _dot(b, b));
  return length == 0 ? 0 : _dot(a, b) / length;
}

/// The mean of [vectors] (not length 1).
Float32List meanOf(List<Float32List> vectors) {
  final mean = Float32List(
    vectors.isEmpty ? FaceRules.embeddingLength : vectors.first.length,
  );
  if (vectors.isEmpty) return mean;
  for (final v in vectors) {
    for (var i = 0; i < mean.length && i < v.length; i++) {
      mean[i] += v[i];
    }
  }
  for (var i = 0; i < mean.length; i++) {
    mean[i] /= vectors.length;
  }
  return mean;
}

/// A person as the grouping sees it.
typedef GroupPerson = ({int id, Float32List mean, int count});

/// A face not given to anyone yet (newest pictures first). [strong]: big
/// enough to start a new person (see [FaceRules.strongSize]).
typedef NewFace = ({
  int id,
  Float32List embedding,
  bool strong,
  String mediaId,
});

/// What [groupFaces] decided. New people have ids below 0 (-1, -2, …)
/// until the database gives them real ones.
typedef GroupResult = ({
  Map<int, int> personOfFace,
  List<GroupPerson> changed,
  List<GroupPerson> created,
});

/// How close a face (length 1) is to a person: the AVERAGE cosine to each
/// of the person's faces = face · mean. (Not the cosine to the mean: the
/// mean of a big group drifts towards an "everyone" face and would then
/// pull in strangers.)
double personScore(Float32List face, Float32List mean) => _dot(face, mean);

Float32List _unit(Float32List v) {
  final length = math.sqrt(_dot(v, v));
  return length == 0
      ? v
      : Float32List.fromList([for (final x in v) x / length]);
}

/// Groups of faces that belong together (average-linkage clustering):
/// every face starts alone; the two closest groups join, again and again,
/// while the AVERAGE cosine over all their face pairs is at least [join].
/// Unlike "near to any member", one look-alike face cannot glue two people
/// together. Groups smaller than [minFaces] are left out. [faces] must have
/// length 1. Returns groups of indexes, biggest first.
///
/// Nearest-neighbour chain: O(n²) time and memory (n × n similarities).
List<List<int>> averageGroups(
  List<Float32List> faces, {
  double join = FaceRules.joinGroups,
  int minFaces = FaceRules.minFacesForPerson,
  List<String>? pictures,
}) {
  final n = faces.length;
  if (n == 0) return const [];
  final sim = Float32List(n * n);
  for (var i = 0; i < n; i++) {
    for (var j = i + 1; j < n; j++) {
      // Two faces of the SAME picture are two different people.
      final s = pictures != null && pictures[i] == pictures[j]
          ? -1.0
          : _dot(faces[i], faces[j]);
      sim[i * n + j] = s;
      sim[j * n + i] = s;
    }
  }
  final size = List<int>.filled(n, 1);
  final alive = List<bool>.filled(n, true);
  // Done: its closest group is below [join], it will never join again.
  final done = List<bool>.filled(n, false);
  final members = [
    for (var i = 0; i < n; i++) [i],
  ];
  final chain = <int>[];
  var next = 0;

  while (true) {
    if (chain.isEmpty) {
      while (next < n && (!alive[next] || done[next])) {
        next++;
      }
      if (next >= n) break;
      chain.add(next);
    }
    final a = chain.last;
    final previous = chain.length >= 2 ? chain[chain.length - 2] : -1;
    var best = -1;
    var bestSim = double.negativeInfinity;
    for (var k = 0; k < n; k++) {
      if (k == a || !alive[k] || done[k]) continue;
      final s = sim[a * n + k];
      if (s > bestSim || (s == bestSim && k == previous)) {
        bestSim = s;
        best = k;
      }
    }
    if (best < 0 || bestSim < join) {
      done[a] = true;
      chain.removeLast();
      continue;
    }
    if (best != previous) {
      chain.add(best);
      continue;
    }
    // a and b are each other's closest: join b into a.
    chain
      ..removeLast()
      ..removeLast();
    final b = best;
    final total = size[a] + size[b];
    for (var k = 0; k < n; k++) {
      if (!alive[k] || k == a || k == b) continue;
      final s = (size[a] * sim[a * n + k] + size[b] * sim[b * n + k]) / total;
      sim[a * n + k] = s;
      sim[k * n + a] = s;
    }
    size[a] = total;
    alive[b] = false;
    members[a].addAll(members[b]);
  }

  return [
    for (var i = 0; i < n; i++)
      if (alive[i] && size[i] >= minFaces) members[i],
  ]..sort((x, y) => y.length.compareTo(x.length));
}

/// Gives the new faces to people. Pure (runs in an isolate).
///  1. A face goes to the known person it is closest to, when the score
///     ([personScore]) reaches [FaceRules.samePerson]
///     ([FaceRules.weakSamePerson] for a small face).
///  2. The strong faces left over that form groups ([averageGroups]) become
///     new people.
///  3. Again from 1 (a few rounds), so faces can join the people just made.
///  4. The rest stay new (not in [GroupResult.personOfFace]): they are tried
///     again next time, when more faces have come in.
GroupResult groupFaces(List<GroupPerson> people, List<NewFace> faces) {
  // Work with sums: face · sum / count = face · mean (one dot product).
  final ids = <int>[];
  final sums = <Float32List>[];
  final counts = <int>[];
  for (final person in people) {
    final sum = Float32List(person.mean.length);
    for (var i = 0; i < sum.length; i++) {
      sum[i] = person.mean[i] * person.count;
    }
    ids.add(person.id);
    sums.add(sum);
    counts.add(person.count);
  }
  final known = people.length;
  final touched = <int>{};
  final personOfFace = <int, int>{};

  void add(int p, Float32List e) {
    final sum = sums[p];
    for (var i = 0; i < sum.length && i < e.length; i++) {
      sum[i] += e[i];
    }
    counts[p]++;
  }

  var waiting = [
    for (final face in faces)
      if (_dot(_unit(face.embedding), _unit(face.embedding)) > 0)
        (
          id: face.id,
          e: _unit(face.embedding),
          strong: face.strong,
          picture: face.mediaId,
        ),
  ];

  // A person is in a picture once: the pictures each person got here.
  final picturesOf = <int, Set<String>>{};

  // Rounds: the people made in a round can take in faces in the next one.
  for (var round = 0; round < 4 && waiting.isNotEmpty; round++) {
    final given = personOfFace.length;

    // 1. Known (and just made) people.
    final left = <({int id, Float32List e, bool strong, String picture})>[];
    for (final face in waiting) {
      var best = -1;
      var bestScore = face.strong
          ? FaceRules.samePerson
          : FaceRules.weakSamePerson;
      for (var p = 0; p < sums.length; p++) {
        if (picturesOf[p]?.contains(face.picture) ?? false) continue;
        final score = _dot(face.e, sums[p]) / counts[p];
        if (score >= bestScore) {
          bestScore = score;
          best = p;
        }
      }
      if (best >= 0) {
        add(best, face.e);
        touched.add(best);
        personOfFace[face.id] = ids[best];
        (picturesOf[best] ??= {}).add(face.picture);
      } else {
        left.add(face);
      }
    }

    // 2. New people from groups of the strong faces left.
    final strong = [
      for (final f in left)
        if (f.strong) f,
    ].take(FaceRules.maxFacesPerGrouping).toList();
    final grouped = <int>{};
    for (final members in averageGroups(
      [for (final f in strong) f.e],
      pictures: [for (final f in strong) f.picture],
    )) {
      final p = sums.length;
      ids.add(-(p - known + 1));
      sums.add(Float32List(strong[members.first].e.length));
      counts.add(0);
      for (final m in members) {
        add(p, strong[m].e);
        personOfFace[strong[m].id] = ids[p];
        (picturesOf[p] ??= {}).add(strong[m].picture);
        grouped.add(strong[m].id);
      }
    }
    waiting = [
      for (final f in left)
        if (!grouped.contains(f.id)) f,
    ];
    if (personOfFace.length == given) break;
  }

  GroupPerson asPerson(int p) {
    final mean = Float32List(sums[p].length);
    for (var i = 0; i < mean.length; i++) {
      mean[i] = sums[p][i] / counts[p];
    }
    return (id: ids[p], mean: mean, count: counts[p]);
  }

  return (
    personOfFace: personOfFace,
    changed: [
      for (final p in touched)
        if (p < known) asPerson(p),
    ],
    created: [for (var p = known; p < sums.length; p++) asPerson(p)],
  );
}

/// How good a face is as a cover / featured picture: big and sharp.
double faceQuality({required double size, required double sharpness}) =>
    size * math.log(1 + math.max(0, sharpness));

/// What the People page needs to know about a person.
typedef PersonStanding = ({int id, bool? shown, int pictures, int changedAt});

/// Who is on the People page: those added with "+", plus (when the user
/// has not decided) the [FaceRules.maxAutoShown] people with the most
/// pictures, at least [FaceRules.minPicturesShown]. Hidden ones never.
/// Order: changed by the user (named, cover, merged, added) newest first,
/// then most pictures.
List<int> peopleOnPage(List<PersonStanding> people) {
  final auto = [
    for (final p in people)
      if (p.shown == null && p.pictures >= FaceRules.minPicturesShown) p,
  ]..sort((a, b) => b.pictures.compareTo(a.pictures));
  final autoIds = {for (final p in auto.take(FaceRules.maxAutoShown)) p.id};
  final on =
      [
        for (final p in people)
          if (p.shown ?? autoIds.contains(p.id)) p,
      ]..sort((a, b) {
        final changed = b.changedAt.compareTo(a.changedAt);
        if (changed != 0) return changed;
        final pictures = b.pictures.compareTo(a.pictures);
        return pictures != 0 ? pictures : a.id.compareTo(b.id);
      });
  return [for (final p in on) p.id];
}

/// People close to [person] but not merged ("Similar people have been
/// detected"), closest first. Close = the AVERAGE cosine between their
/// faces (mean · mean): one person split in two scores high, two people
/// low. (The cosine of the two means was high for any two big groups.)
List<int> similarPeople(GroupPerson person, List<GroupPerson> others) {
  final scored = [
    for (final other in others)
      if (other.id != person.id)
        (id: other.id, score: _dot(person.mean, other.mean)),
  ]..retainWhere((s) => s.score >= FaceRules.similarPeople);
  scored.sort((a, b) => b.score.compareTo(a.score));
  return [for (final s in scored) s.id];
}

/// What [featuredPictures] needs to know about a face.
typedef FeaturedCandidate = ({String mediaId, double quality, int takenMs});

/// The person page's featured pictures (and its slideshow): at most [max],
/// the best face of each DAY first (so the same moment does not fill the
/// list), then the next best ones; newest first.
List<String> featuredPictures(
  List<FeaturedCandidate> faces, {
  int max = FaceRules.maxFeatured,
}) {
  final best = <String, FeaturedCandidate>{};
  for (final face in faces) {
    final known = best[face.mediaId];
    if (known == null || face.quality > known.quality) {
      best[face.mediaId] = face;
    }
  }
  final byQuality = best.values.toList()
    ..sort((a, b) => b.quality.compareTo(a.quality));
  String dayOf(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.year}-${d.month}-${d.day}';
  }

  final chosen = <FeaturedCandidate>[];
  final days = <String>{};
  for (final face in byQuality) {
    if (chosen.length >= max) break;
    if (days.add(dayOf(face.takenMs))) chosen.add(face);
  }
  for (final face in byQuality) {
    if (chosen.length >= max) break;
    if (!chosen.contains(face)) chosen.add(face);
  }
  chosen.sort((a, b) => b.takenMs.compareTo(a.takenMs));
  return [for (final face in chosen) face.mediaId];
}

/// A person's pictures are shown like an album: its id on the shared grid,
/// the viewer and the actions.
String personAlbumId(int personId) => 'person:$personId';

/// The person of a [personAlbumId] (null = not a person).
int? personIdOfAlbum(String? albumId) =>
    albumId != null && albumId.startsWith('person:')
    ? int.tryParse(albumId.substring('person:'.length))
    : null;
