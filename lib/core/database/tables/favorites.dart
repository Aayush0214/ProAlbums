import 'package:drift/drift.dart';

/// Photos / videos the person marked with the heart.
///
/// Kept in OUR database (not in the phone's media database): the heart works
/// at once, with no system permission dialog, and on every platform.
class Favorites extends Table {
  /// The photo_manager id of the photo / video.
  TextColumn get mediaId => text()();

  DateTimeColumn get addedAt => dateTime()();

  /// File name and folder of the photo ("IMG_1.jpg", "DCIM/Camera/").
  ///
  /// The media id can change after a reinstall or on a new phone; the name +
  /// folder lets a backup find the same file again. Filled in when the
  /// favorite is read (null until then, old rows have none).
  TextColumn get displayName => text().nullable()();

  TextColumn get relativePath => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {mediaId};
}
