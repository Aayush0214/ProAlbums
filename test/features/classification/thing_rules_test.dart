import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/features/classification/domain/thing_rules.dart';

void main() {
  test('stored labels are read back', () {
    expect(parseLabels('Car:0.83,Fast food:0.71'), {
      'Car': 0.83,
      'Fast food': 0.71,
    });
    expect(parseLabels(''), isEmpty);
  });

  test('a sure label puts a picture in its things', () {
    expect(thingsOf({'Car': 0.9, 'Sunglasses': 0.8}, null), {
      ThingKind.cars,
      ThingKind.accessories,
    });
  });

  test('an unsure label does not', () {
    expect(thingsOf({'Car': 0.55}, null), isEmpty);
  });

  test('a crop field is not food', () {
    expect(thingsOf({'Food': 0.9, 'Field': 0.8}, null), isEmpty);
    expect(thingsOf({'Food': 0.9}, null), {ThingKind.food});
  });

  test('a bike is not a car', () {
    expect(thingsOf({'Bumper': 0.8, 'Motorcycle': 0.6}, null), isEmpty);
    expect(thingsOf({'Bumper': 0.8, 'Motorcycle': 0.9}, null), {
      ThingKind.motorbikes,
    });
  });

  test('a picture of a person is no plants picture', () {
    const person = (faces: 1, clear: 1, biggest: 0.3);
    expect(thingsOf({'Plant': 0.9}, person), isEmpty);
    expect(thingsOf({'Plant': 0.9}, null), {ThingKind.plants});
  });

  group('documents (by the text read)', () {
    const lots = (chars: 400, area: 0.4, screenshot: false);
    const some = (chars: 50, area: 0.05, screenshot: false);

    test('a picture full of text is a document, no label needed', () {
      // A car's RC, a made-up diet plan: no document label at all.
      expect(thingsOf({}, null, text: lots), {ThingKind.documents});
    });

    test('a document label needs some text', () {
      expect(thingsOf({'Paper': 0.9}, null, text: some), {ThingKind.documents});
      expect(thingsOf({'Poster': 0.9}, null), isEmpty);
    });

    test('people with a banner behind them are no document', () {
      const person = (faces: 2, clear: 2, biggest: 0.2);
      const banner = (chars: 80, area: 0.15, screenshot: false);
      expect(thingsOf({'Poster': 0.9}, person, text: banner), isEmpty);
    });

    test('an ID card held close still is (its photo is small)', () {
      const idPhoto = (faces: 1, clear: 1, biggest: 0.11);
      expect(thingsOf({}, idPhoto, text: lots), {ThingKind.documents});
    });

    test('a car with its name on it is no document', () {
      expect(thingsOf({'Car': 0.9}, null, text: lots), {ThingKind.cars});
    });

    test('a short logo text is no document', () {
      const logo = (chars: 35, area: 0.2, screenshot: false);
      expect(thingsOf({}, null, text: logo), isEmpty);
    });

    test('a small face with a little text is no document', () {
      const kid = (faces: 1, clear: 0, biggest: 0.05);
      const little = (chars: 60, area: 0.05, screenshot: false);
      expect(thingsOf({}, kid, text: little), isEmpty);
    });

    test('never a screenshot or a selfie', () {
      const chat = (chars: 900, area: 0.7, screenshot: true);
      expect(thingsOf({}, null, text: chat), isEmpty);
      expect(
        thingsOf({}, null, camera: 'front', text: lots),
        isNot(contains(ThingKind.documents)),
      );
    });
  });

  group('selfie', () {
    const face = (faces: 1, clear: 1, biggest: 0.5);

    test('front camera with a face is a selfie', () {
      expect(thingsOf({}, face, camera: 'front'), {ThingKind.selfie});
    });

    test('the back camera never is, even when the label says so', () {
      expect(thingsOf({'Selfie': 0.95}, face, camera: 'back'), isEmpty);
    });

    test('no camera data: only a very sure Selfie label', () {
      expect(thingsOf({'Selfie': 0.9}, face), {ThingKind.selfie});
      expect(thingsOf({'Selfie': 0.8}, face), isEmpty);
    });

    test('front camera without a face (a view) is no selfie', () {
      expect(thingsOf({}, null, camera: 'front'), isEmpty);
    });
  });

  test('faces make group photos', () {
    expect(thingsOf({}, (faces: 5, clear: 4, biggest: 0.15)), {
      ThingKind.groupPhoto,
    });
    // Many tiny faces far behind are no group photo.
    expect(thingsOf({}, (faces: 6, clear: 1, biggest: 0.11)), isEmpty);
  });

  test('albums: non-empty only, newest first, blackboard marked', () {
    final albums = thingAlbums([
      (id: 'a', takenMs: 1, labels: 'Flower:0.9', camera: '', text: noText),
      (
        id: 'b',
        takenMs: 5,
        labels: 'Flower:0.8,Petal:0.75',
        camera: '',
        text: noText,
      ),
      (
        id: 'c',
        takenMs: 3,
        labels: 'Blackboard:0.9',
        camera: '',
        text: (chars: 60, area: 0.2, screenshot: false),
      ),
      (id: 'd', takenMs: 4, labels: 'Sky:0.9', camera: '', text: noText),
    ], const {});
    expect(
      albums.keys,
      unorderedEquals([ThingKind.flower, ThingKind.documents]),
    );
    expect(albums[ThingKind.flower]!.map((p) => p.id), ['b', 'a']);
    expect(albums[ThingKind.documents]!.single.blackboard, isTrue);
  });

  test('"Remove this type" takes a picture out of that thing only', () {
    final albums = thingAlbums(
      [
        (
          id: 'a',
          takenMs: 1,
          labels: 'Flower:0.9,Car:0.9',
          camera: '',
          text: noText,
        ),
      ],
      const {},
      removed: {
        ThingKind.flower: {'a'},
      },
    );
    expect(albums.keys, [ThingKind.cars]);
  });

  test('a thing is shown like an album', () {
    expect(thingOfAlbum(thingAlbumId(ThingKind.cars)), ThingKind.cars);
    expect(thingOfAlbum('place:Ujjain'), isNull);
  });
}
