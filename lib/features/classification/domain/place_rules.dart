/// Numbers for Location (change here only).
abstract final class PlaceRules {
  /// A place the Geocoder could not name is asked again after this.
  static const Duration retryAfter = Duration(days: 1);

  /// Places asked per scan (the Geocoder is a network service: asked one by
  /// one, the rest next time).
  static const int maxNamesPerScan = 400;
}

/// The small square of the map a picture is in: 0.01° (≈ 1.1 km), so the
/// pictures of one walk share one name (asked once).
String placeCellOf(double lat, double lng) =>
    '${lat.toStringAsFixed(2)},${lng.toStringAsFixed(2)}';

/// The middle of a [placeCellOf] square (what the Geocoder is asked).
({double lat, double lng}) placeCellCenter(String cell) {
  final parts = cell.split(',');
  return (lat: double.parse(parts[0]), lng: double.parse(parts[1]));
}

/// The album name of an address: the town / village, else the district,
/// else the state, else the country (like the system gallery: "Ambikapur",
/// "Ujjain Division"). null = nothing usable.
String? placeNameFrom(Map<String, String?> address) {
  for (final key in ['locality', 'subAdminArea', 'adminArea', 'country']) {
    final value = address[key]?.trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

/// The viewer's place line (like the system gallery): neighbourhood (else
/// town) + district, without repeats — "Khilachipur-Ujjain Division".
/// null = nothing usable.
String? placeLabelFrom(Map<String, String?> address) {
  final parts = <String>[];
  for (final value in [
    address['subLocality'] ?? address['locality'],
    address['subAdminArea'],
  ]) {
    final part = value?.trim();
    if (part != null && part.isNotEmpty && !parts.contains(part)) {
      parts.add(part);
    }
  }
  return parts.isEmpty ? placeNameFrom(address) : parts.join('-');
}

/// A picture with a place.
typedef PlacedPicture = ({String id, int takenMs, String cell});

/// A place album: its name and pictures (newest first).
typedef PlaceAlbum = ({String name, List<PlacedPicture> pictures});

/// The place albums: pictures whose square has a name, by name; most
/// pictures first (then by name).
List<PlaceAlbum> placeAlbums(
  List<PlacedPicture> pictures,
  Map<String, String> nameOfCell,
) {
  final byName = <String, List<PlacedPicture>>{};
  for (final picture in pictures) {
    final name = nameOfCell[picture.cell];
    if (name == null) continue;
    (byName[name] ??= []).add(picture);
  }
  final albums = [
    for (final entry in byName.entries)
      (
        name: entry.key,
        pictures: entry.value..sort((a, b) => b.takenMs.compareTo(a.takenMs)),
      ),
  ];
  albums.sort((a, b) {
    final count = b.pictures.length.compareTo(a.pictures.length);
    return count != 0 ? count : a.name.compareTo(b.name);
  });
  return albums;
}

/// A place is shown like an album (grid, viewer, actions).
String placeAlbumId(String name) => 'place:$name';
