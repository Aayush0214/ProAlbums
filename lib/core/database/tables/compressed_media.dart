import 'package:drift/drift.dart';

/// Copies made by "Compress size". Android does not know a file was
/// compressed, so the grid's badge (zip icon + size, videos) reads it here.
class CompressedMedia extends Table {
  /// The photo_manager id of the NEW (smaller) copy.
  TextColumn get mediaId => text()();

  /// Its size in bytes (shown on the badge, e.g. "12.6M").
  IntColumn get sizeBytes => integer()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {mediaId};
}
