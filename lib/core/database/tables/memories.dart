import 'package:drift/drift.dart';

/// For You > Memories: the memories made from the pictures (MemoryRules)
/// and what the user changed in them.
@DataClassName('MemoryRow')
class Memories extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// The rules' stable name ("day:2025-10-22", "person:7"): the same
  /// memory is found again on the next run.
  TextColumn get key => text().unique()();

  /// MemoryKind name.
  TextColumn get kind => text()();

  /// The rules' title; [customTitle] = Rename.
  TextColumn get title => text()();
  TextColumn get customTitle => text().nullable()();

  IntColumn get startMs => integer()();
  IntColumn get endMs => integer()();

  /// The rules' cover; [coverId] = Set as cover.
  TextColumn get autoCoverId => text()();
  TextColumn get coverId => text().nullable()();

  /// The user changed its pictures (Gallery management, Remove, Set as
  /// cover, made from a person page): the rules no longer touch them.
  BoolColumn get edited => boolean().withDefault(const Constant(false))();

  /// Delete memories: kept as a mark so the rules never make it again.
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  IntColumn get updatedAt => integer()();
}

/// The pictures of a memory: every candidate, [shown] = in the video and
/// View Gallery (at most MemoryRules.maxShown).
class MemoryItems extends Table {
  IntColumn get memoryId => integer()();
  TextColumn get mediaId => text()();
  IntColumn get takenMs => integer()();
  BoolColumn get shown => boolean()();

  @override
  Set<Column<Object>> get primaryKey => {memoryId, mediaId};
}
