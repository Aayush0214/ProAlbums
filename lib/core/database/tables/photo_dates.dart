import 'package:drift/drift.dart';

/// When a picture was taken, read from its EXIF, for pictures MediaStore
/// has no DATE_TAKEN for (copied from another phone…). Read once, again
/// only when the file changed ([modified]).
class PhotoDates extends Table {
  TextColumn get mediaId => text()();

  /// MediaStore DATE_MODIFIED (seconds) when it was read.
  IntColumn get modified => integer()();

  /// ms; null = the EXIF has no date either.
  IntColumn get takenMs => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {mediaId};
}
