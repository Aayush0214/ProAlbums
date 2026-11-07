import 'package:drift/drift.dart';

/// Intelligent classification > Location: where each picture was taken
/// (read once; again only when the file changed: [modified]).
class PhotoLocations extends Table {
  TextColumn get mediaId => text()();

  /// MediaStore DATE_MODIFIED (seconds) when it was read.
  IntColumn get modified => integer()();

  /// When the picture was taken (ms), for the newest-first order.
  IntColumn get takenMs => integer()();

  /// GPS place from the picture's EXIF (null = none).
  RealColumn get lat => real().nullable()();
  RealColumn get lng => real().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {mediaId};
}

/// The name of a small square of the map (~1 km, see placeCellOf), asked
/// once from Android's Geocoder.
class PlaceNames extends Table {
  /// "lat,lng" rounded to the square.
  TextColumn get cell => text()();

  /// The album name (town / village, else district); null = the Geocoder
  /// could not answer (asked again later).
  TextColumn get name => text().nullable()();

  /// The viewer's place line: neighbourhood / town + district
  /// ("Khilachipur-Ujjain Division"); null = not asked yet / no answer.
  TextColumn get label => text().nullable()();

  /// Search: the neighbourhood ("Chingrajpara"); "" = none, null = not
  /// asked yet (named before Search existed: asked once more).
  TextColumn get area => text().nullable()();

  /// When it was asked (ms).
  IntColumn get checkedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {cell};
}
