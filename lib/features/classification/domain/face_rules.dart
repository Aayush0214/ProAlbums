import 'dart:math' as math;
import 'dart:typed_data';

/// Numbers for People (tuned on the phone; change here only).
abstract final class FaceRules {
  /// A face joins a person when its average cosine to the person's faces
  /// is at least this (SFace's own same-person line for one pair is
  /// 0.363). Higher = fewer mix-ups, more split people (Merge fixes those).
  static const double samePerson = 0.36;

  /// Change when the grouping rules change: every face is grouped again
  /// (the faces themselves are kept; user changes are lost — fine before
  /// the People pages exist).
  static const int groupingVersion = 2;

  /// Two people at least this close (but not [samePerson]) are offered as
  /// "Similar people have been detected. Merge now".
  static const double similarPeople = 0.35;

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

/// A face not given to anyone yet (newest pictures first).
typedef NewFace = ({int id, Float32List embedding});

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

/// Gives each new face to the closest person when close enough
/// ([FaceRules.samePerson], see [personScore]); otherwise it starts a new
/// person. Pure (runs in an isolate).
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

  for (final face in faces) {
    final eNorm = math.sqrt(_dot(face.embedding, face.embedding));
    if (eNorm == 0) continue;
    final e = Float32List.fromList([for (final v in face.embedding) v / eNorm]);
    var best = -1;
    var bestScore = FaceRules.samePerson;
    for (var p = 0; p < sums.length; p++) {
      final score = _dot(e, sums[p]) / counts[p];
      if (score >= bestScore) {
        bestScore = score;
        best = p;
      }
    }
    if (best < 0) {
      ids.add(-(sums.length - known + 1));
      sums.add(e);
      counts.add(1);
      best = sums.length - 1;
    } else {
      final sum = sums[best];
      for (var i = 0; i < sum.length && i < e.length; i++) {
        sum[i] += e[i];
      }
      counts[best]++;
    }
    touched.add(best);
    personOfFace[face.id] = ids[best];
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
/// detected"), closest first.
List<int> similarPeople(GroupPerson person, List<GroupPerson> others) {
  final scored = [
    for (final other in others)
      if (other.id != person.id)
        (id: other.id, score: faceCosine(person.mean, other.mean)),
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
