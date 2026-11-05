/// Numbers for the things (change here only).
abstract final class ThingRules {
  /// A label counts when ML Kit is at least this sure.
  static const double minConfidence = 0.7;

  /// A [ThingKind.notWith] label keeps a picture out from this sure.
  static const double notWithConfidence = 0.5;

  /// Group photo: at least this many CLEAR faces ([clearFaceSize]; small
  /// faces far behind do not count).
  static const int groupFaces = 3;
  static const double clearFaceSize = 0.10;

  /// A face at least this big (share of the short side) makes a picture
  /// "of a person": not a document (an ID card's photo is smaller), not a
  /// plants picture (grass behind someone).
  static const double bigFaceSize = 0.12;

  /// The "Selfie" label alone (no camera data, e.g. a WhatsApp copy) must
  /// be this sure.
  static const double selfieLabelAlone = 0.85;

  /// Documents (see isDocument): characters + share of the picture covered
  /// by text for a text-heavy picture...
  static const int docChars = 50;
  static const double docArea = 0;

  /// ...some text with a document label...
  static const int docCharsWithLabel = 15;

  /// ...and a picture of people only when text covers most of it.
  static const int docCharsWithPeople = 100;
  static const double docAreaWithPeople = 0.18;

  /// Change when LabelChannel reads pictures differently: every picture is
  /// looked at again (2: + which camera, 3: + text read, 1024 px).
  static const int scanVersion = 3;
}

/// The things of Intelligent classification, in the system gallery's
/// order. A picture can be in several (a selfie with sunglasses).
enum ThingKind {
  documents(
    'Documents',
    {
      'Paper',
      'Receipt',
      'Menu',
      'Poster',
      'Newspaper',
      'Passport',
      'Whiteboard',
      'Blackboard',
      'Presentation',
    },
    0.75,
    // A car or bike with its name on it, a logo on a sunset, a crowd at an
    // event with banners: text, but no document.
    {'Car', 'Motorcycle', 'Vehicle', 'Sunset', 'Sky', 'Crowd', 'Event', 'Team'},
  ),
  groupPhoto('Group photo', {}),
  // Decided by the camera + faces (see thingsOf), the label only helps.
  selfie('Selfie', {}),
  plants(
    'Plants',
    {'Plant', 'Flora', 'Garden', 'Forest', 'Jungle', 'Branch', 'Twig'},
    0.65,
    {},
    true,
  ),
  food(
    'Food',
    {
      'Food',
      'Fast food',
      'Cuisine',
      'Meal',
      'Lunch',
      'Supper',
      'Fruit',
      'Vegetable',
      'Cake',
      'Pie',
      'Cookie',
      'Bread',
      'Pizza',
      'Cheeseburger',
      'Hot dog',
      'Bento',
      'Sushi',
      'Gelato',
      'Juice',
      'Coffee',
      'Cappuccino',
    },
    0.85,
    {'Field', 'Prairie', 'Farm', 'Plant', 'Flora'},
  ),
  building('Building', {
    'Building',
    'Skyline',
    'Skyscraper',
    'Tower',
    'Church',
    'Cathedral',
    'Temple',
    'Mosque',
    'Palace',
    'Castle',
    'Monument',
    'Ruins',
    'Lighthouse',
    'Museum',
    'Stadium',
  }),
  accessories('Accessories', {
    'Sunglasses',
    'Glasses',
    'Goggles',
    'Jewellery',
    'Necklace',
    'Bracelet',
    'Bangle',
    'Ring',
    'Hat',
    'Cap',
    'Beanie',
    'Handbag',
    'Bag',
    'Tie',
    'Scarf',
  }, 0.75),
  flower('Flower', {'Flower', 'Petal', 'Flowerpot'}),
  // A bike's handlebar can look like a car part: bikes stay out.
  cars('Cars', {'Car', 'Van', 'Bumper', 'Windshield'}, 0.7, {'Motorcycle'}),
  motorbikes('Motorbikes', {'Motorcycle'}, 0.85);

  const ThingKind(
    this.title,
    this.labels, [
    this.minConfidence = ThingRules.minConfidence,
    this.notWith = const {},
    this.noBigFace = false,
  ]);

  final String title;

  /// ML Kit labels that put a picture here.
  final Set<String> labels;

  /// How sure ML Kit must be for this thing.
  final double minConfidence;

  /// Labels that keep a picture OUT (a rice field is "Food" to ML Kit).
  final Set<String> notWith;

  /// A picture of a person (a big face) is never this thing.
  final bool noBigFace;
}

/// "Label:0.83,Label:0.71" (as stored) → label → confidence.
Map<String, double> parseLabels(String text) {
  final out = <String, double>{};
  for (final part in text.split(',')) {
    final i = part.lastIndexOf(':');
    if (i <= 0) continue;
    final confidence = double.tryParse(part.substring(i + 1));
    if (confidence != null) out[part.substring(0, i)] = confidence;
  }
  return out;
}

/// The faces of a picture (from People's scan).
typedef FaceStats = ({int faces, int clear, double biggest});

/// The text read in a picture (for Documents).
typedef TextSeen = ({int chars, double area, bool screenshot});

const TextSeen noText = (chars: 0, area: 0, screenshot: false);

/// Is a picture a document? By the TEXT in it (labels alone missed a car's
/// RC and made-up infographics, and called banners behind people "Poster"):
///  - never a screenshot (chats are full of text) or a front-camera picture;
///  - no car / bike (a name on it is text);
///  - a picture with any face only when text covers a good part of it (an
///    ID card held close);
///  - else: plenty of text over a good part of the picture, or a document
///    label with some text.
bool isDocument(
  Map<String, double> labels,
  FaceStats? faces,
  String camera,
  TextSeen text,
) {
  if (text.screenshot || camera == 'front') return false;
  final people = (faces?.faces ?? 0) > 0;
  // A car or bike, a sunset, a crowd… (see ThingKind.documents.notWith).
  if (ThingKind.documents.notWith.any(
    (l) => (labels[l] ?? 0) >= ThingRules.notWithConfidence,
  )) {
    return false;
  }
  if (people) {
    return text.area >= ThingRules.docAreaWithPeople &&
        text.chars >= ThingRules.docCharsWithPeople;
  }
  final textHeavy =
      text.chars >= ThingRules.docChars && text.area >= ThingRules.docArea;
  final docLabel = ThingKind.documents.labels.any(
    (l) => (labels[l] ?? 0) >= ThingKind.documents.minConfidence,
  );
  return textHeavy || (docLabel && text.chars >= ThingRules.docCharsWithLabel);
}

/// The things a picture is in. [camera]: "front" / "back" / "" (unknown).
///  - Documents: see [isDocument].
///  - Selfie: the FRONT camera with a face in it; never the back camera;
///    no camera data → only a very sure "Selfie" label.
///  - Group photo: at least 3 clear faces.
///  - The rest: their labels, minus [ThingKind.notWith] and, for
///    [ThingKind.noBigFace], pictures of a person.
Set<ThingKind> thingsOf(
  Map<String, double> labels,
  FaceStats? faces, {
  String camera = '',
  TextSeen text = noText,
}) {
  final bigFace = (faces?.biggest ?? 0) >= ThingRules.bigFaceSize;
  final out = <ThingKind>{
    for (final kind in ThingKind.values)
      if (kind != ThingKind.documents &&
          kind.labels.any((l) => (labels[l] ?? 0) >= kind.minConfidence) &&
          !kind.notWith.any(
            (l) => (labels[l] ?? 0) >= ThingRules.notWithConfidence,
          ) &&
          !(kind.noBigFace && bigFace))
        kind,
  };
  if (isDocument(labels, faces, camera, text)) out.add(ThingKind.documents);
  if (faces != null && faces.clear >= ThingRules.groupFaces) {
    out.add(ThingKind.groupPhoto);
  }
  final selfie = switch (camera) {
    'front' => (faces?.faces ?? 0) > 0,
    'back' => false,
    _ => (labels['Selfie'] ?? 0) >= ThingRules.selfieLabelAlone,
  };
  if (selfie) out.add(ThingKind.selfie);
  return out;
}

/// Documents' "Blackboard writing" chip.
bool isBlackboardWriting(Map<String, double> labels) =>
    (labels['Blackboard'] ?? 0) >= ThingRules.minConfidence ||
    (labels['Whiteboard'] ?? 0) >= ThingRules.minConfidence;

/// A looked-at picture.
typedef LabeledPicture = ({
  String id,
  int takenMs,
  String labels,
  String camera,
  TextSeen text,
});

/// A picture in a thing album.
typedef ThingPicture = ({String id, int takenMs, bool blackboard});

/// Every thing album (only the non-empty ones), newest picture first.
/// [removed]: "Remove this type" (kind → ids).
Map<ThingKind, List<ThingPicture>> thingAlbums(
  List<LabeledPicture> pictures,
  Map<String, FaceStats> faces, {
  Map<ThingKind, Set<String>> removed = const {},
}) {
  final out = <ThingKind, List<ThingPicture>>{};
  for (final picture in pictures) {
    final labels = parseLabels(picture.labels);
    final kinds = thingsOf(
      labels,
      faces[picture.id],
      camera: picture.camera,
      text: picture.text,
    );
    if (kinds.isEmpty) continue;
    final entry = (
      id: picture.id,
      takenMs: picture.takenMs,
      blackboard: isBlackboardWriting(labels),
    );
    for (final kind in kinds) {
      if (removed[kind]?.contains(picture.id) ?? false) continue;
      (out[kind] ??= []).add(entry);
    }
  }
  for (final list in out.values) {
    list.sort((a, b) => b.takenMs.compareTo(a.takenMs));
  }
  return out;
}

/// A thing is shown like an album (grid, viewer, actions).
String thingAlbumId(ThingKind kind) => 'thing:${kind.name}';

/// The thing of a [thingAlbumId] (null = not a thing).
ThingKind? thingOfAlbum(String? albumId) {
  if (albumId == null || !albumId.startsWith('thing:')) return null;
  final name = albumId.substring('thing:'.length);
  for (final kind in ThingKind.values) {
    if (kind.name == name) return kind;
  }
  return null;
}
