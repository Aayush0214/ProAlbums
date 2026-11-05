import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:proalbums/core/database/tables/cleanup_fingerprints.dart';
import 'package:proalbums/core/database/tables/compressed_media.dart';
import 'package:proalbums/core/database/tables/faces.dart';
import 'package:proalbums/core/database/tables/favorites.dart';
import 'package:proalbums/core/database/tables/places.dart';

part 'app_database.g.dart';

/// The app's own SQLite database.
///
/// Media files themselves stay in MediaStore (read via photo_manager). This DB
/// only stores things the system does not know: favorites, custom albums,
/// hidden-vault records, AI labels, hashes, ...
///
/// Tables are added feature by feature. Every time a table changes: bump
/// [schemaVersion] and add a step in `onUpgrade`.
@DriftDatabase(
  tables: [
    Favorites,
    CompressedMedia,
    CleanupFingerprints,
    FaceScans,
    Faces,
    People,
    FaceRejections,
    PhotoLocations,
    PlaceNames,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Pass an in-memory executor in tests: `AppDatabase(NativeDatabase.memory())`.
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'pro_album'));

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // Version 2: favorites.
          if (from < 2) await m.createTable(favorites);
          // Version 3: name + folder of a favorite (for backup / restore).
          if (from == 2) {
            await m.addColumn(favorites, favorites.displayName);
            await m.addColumn(favorites, favorites.relativePath);
          }
          // Version 4: copies made by Compress size (grid badge).
          if (from < 4) await m.createTable(compressedMedia);
          // Version 5: Cleanup suggestions fingerprints.
          if (from < 5) await m.createTable(cleanupFingerprints);
          // Version 6: Intelligent classification > People.
          if (from < 6) {
            await m.createTable(faceScans);
            await m.createTable(faces);
            await m.createIndex(facesMedia);
            await m.createIndex(facesPerson);
            await m.createTable(people);
            await m.createTable(faceRejections);
          }
          // Version 7: Intelligent classification > Location.
          if (from < 7) {
            await m.createTable(photoLocations);
            await m.createTable(placeNames);
          }
          // Version 8: the viewer's place line.
          if (from == 7) await m.addColumn(placeNames, placeNames.label);
        },
      );
}
