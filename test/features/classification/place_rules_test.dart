import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/features/classification/domain/place_rules.dart';

void main() {
  test('pictures about 1 km apart share a square', () {
    expect(placeCellOf(23.1821, 75.7764), '23.18,75.78');
    expect(placeCellOf(23.1849, 75.7749), '23.18,75.77');
    final center = placeCellCenter('23.18,75.78');
    expect(center.lat, 23.18);
    expect(center.lng, 75.78);
  });

  test('the name is the town, else the district, state, country', () {
    expect(
      placeNameFrom({'locality': 'Ambikapur', 'subAdminArea': 'Surguja'}),
      'Ambikapur',
    );
    expect(
      placeNameFrom({'locality': ' ', 'subAdminArea': 'Ujjain Division'}),
      'Ujjain Division',
    );
    expect(placeNameFrom({'country': 'India'}), 'India');
    expect(placeNameFrom({}), isNull);
  });

  test('the viewer line: neighbourhood or town, then district', () {
    expect(
      placeLabelFrom({
        'subLocality': 'Khilachipur',
        'locality': 'Ujjain',
        'subAdminArea': 'Ujjain Division',
      }),
      'Khilachipur-Ujjain Division',
    );
    expect(
      placeLabelFrom({'locality': 'Pune', 'subAdminArea': 'Pune'}),
      'Pune',
    );
    expect(placeLabelFrom({'country': 'India'}), 'India');
  });

  test('albums by name, most pictures first, newest picture first', () {
    final albums = placeAlbums(
      [
        (id: 'a', takenMs: 1, cell: 'x'),
        (id: 'b', takenMs: 3, cell: 'y'),
        (id: 'c', takenMs: 2, cell: 'x'),
        (id: 'd', takenMs: 5, cell: 'z'),
        (id: 'e', takenMs: 9, cell: 'unnamed'),
      ],
      {'x': 'Ujjain', 'y': 'Ujjain', 'z': 'Pune'},
    );
    expect(albums.map((a) => a.name), ['Ujjain', 'Pune']);
    expect(albums.first.pictures.map((p) => p.id), ['b', 'c', 'a']);
  });
}
