import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// The app's own SQLite database.
///
/// Media files themselves stay in MediaStore (read via photo_manager). This DB
/// only stores things the system does not know: custom albums, hidden-vault
/// records, AI labels, hashes, ...
///
/// Tables are added feature by feature (Favorites/Trash in Phase 4, Albums in
/// Phase 5, ...). Every time a table changes: bump [schemaVersion] and add a
/// step in `onUpgrade`.
@DriftDatabase(tables: [])
class AppDatabase extends _$AppDatabase {
  /// Pass an in-memory executor in tests: `AppDatabase(NativeDatabase.memory())`.
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'pro_album'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // if (from < 2) await m.createTable(favorites);
        },
      );
}
