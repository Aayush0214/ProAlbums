import 'package:drift/drift.dart';
import 'package:proalbums/core/database/app_database.dart';
import 'package:proalbums/features/memories/domain/memory_rules.dart';

/// A saved memory as the pages show it.
typedef StoredMemory = ({
  int id,
  String key,
  MemoryKind kind,
  String title,
  int startMs,
  int endMs,
  String coverId,

  /// Shown pictures, oldest first.
  List<String> shown,

  /// Every picture (candidates), oldest first.
  int candidates,
});

/// The memories (Drift): what the rules made, plus the user's changes.
final class MemoryStore {
  const MemoryStore(this._db);

  final AppDatabase _db;

  /// Saves what the rules made ([drafts]); [alive] = pictures that still
  /// exist. A memory nobody edited follows the rules; an edited one only
  /// loses gone pictures; a deleted one is never made again; a memory the
  /// rules no longer make goes (unless edited).
  Future<void> sync(List<MemoryDraft> drafts, Set<String> alive) =>
      _db.transaction(() async {
        final now = DateTime.now().millisecondsSinceEpoch;
        final existing = {
          for (final row in await _db.select(_db.memories).get()) row.key: row,
        };
        final made = <String>{};
        for (final draft in drafts) {
          made.add(draft.key);
          final row = existing[draft.key];
          if (row != null && row.deleted) continue;
          if (row != null && row.edited) {
            await _dropGone(row.id, alive);
            continue;
          }
          final id =
              row?.id ??
              await _db
                  .into(_db.memories)
                  .insert(
                    MemoriesCompanion.insert(
                      key: draft.key,
                      kind: draft.kind.name,
                      title: draft.title,
                      startMs: draft.startMs,
                      endMs: draft.endMs,
                      autoCoverId: draft.coverId,
                      updatedAt: now,
                    ),
                  );
          if (row != null) {
            await (_db.update(
              _db.memories,
            )..where((m) => m.id.equals(id))).write(
              MemoriesCompanion(
                title: Value(draft.title),
                startMs: Value(draft.startMs),
                endMs: Value(draft.endMs),
                autoCoverId: Value(draft.coverId),
                updatedAt: Value(now),
              ),
            );
          }
          await _replaceItems(id, draft);
        }
        for (final row in existing.values) {
          if (made.contains(row.key) || row.deleted) continue;
          if (row.edited) {
            await _dropGone(row.id, alive);
          } else {
            await _deleteRows(row.id);
          }
        }
      });

  Future<void> _replaceItems(int memoryId, MemoryDraft draft) async {
    await (_db.delete(
      _db.memoryItems,
    )..where((i) => i.memoryId.equals(memoryId))).go();
    final shown = draft.shown.toSet();
    await _db.batch((batch) {
      batch.insertAll(_db.memoryItems, [
        for (final (i, id) in draft.ids.indexed)
          MemoryItemsCompanion.insert(
            memoryId: memoryId,
            mediaId: id,
            takenMs: draft.times[i],
            shown: shown.contains(id),
          ),
      ]);
    });
  }

  Future<void> _dropGone(int memoryId, Set<String> alive) async {
    final items = await (_db.select(
      _db.memoryItems,
    )..where((i) => i.memoryId.equals(memoryId))).get();
    final gone = [
      for (final item in items)
        if (!alive.contains(item.mediaId)) item.mediaId,
    ];
    if (gone.isEmpty) return;
    await (_db.delete(
      _db.memoryItems,
    )..where((i) => i.memoryId.equals(memoryId) & i.mediaId.isIn(gone))).go();
  }

  Future<void> _deleteRows(int memoryId) async {
    await (_db.delete(
      _db.memoryItems,
    )..where((i) => i.memoryId.equals(memoryId))).go();
    await (_db.delete(_db.memories)..where((m) => m.id.equals(memoryId))).go();
  }

  /// Every memory with shown pictures (see [compareMemories] for the
  /// order).
  Future<List<StoredMemory>> memories() async {
    final rows = await (_db.select(
      _db.memories,
    )..where((m) => m.deleted.equals(false))).get();
    final items = await (_db.select(
      _db.memoryItems,
    )..orderBy([(i) => OrderingTerm.asc(i.takenMs)])).get();
    final shownOf = <int, List<String>>{};
    final countOf = <int, int>{};
    for (final item in items) {
      countOf[item.memoryId] = (countOf[item.memoryId] ?? 0) + 1;
      if (item.shown) (shownOf[item.memoryId] ??= []).add(item.mediaId);
    }
    final out = <StoredMemory>[];
    for (final row in rows) {
      final shown = shownOf[row.id] ?? const <String>[];
      if (shown.isEmpty) continue;
      final kind = MemoryKind.values.where((k) => k.name == row.kind);
      if (kind.isEmpty) continue;
      final cover = row.coverId ?? row.autoCoverId;
      out.add((
        id: row.id,
        key: row.key,
        kind: kind.first,
        title: row.customTitle ?? row.title,
        startMs: row.startMs,
        endMs: row.endMs,
        coverId: shown.contains(cover) ? cover : shown.first,
        shown: shown,
        candidates: countOf[row.id] ?? 0,
      ));
    }
    out.sort(compareMemories);
    return out;
  }

  /// Delete memories (the pictures stay).
  Future<void> delete(Iterable<int> ids) async {
    final list = ids.toList();
    if (list.isEmpty) return;
    await _db.transaction(() async {
      await (_db.delete(
        _db.memoryItems,
      )..where((i) => i.memoryId.isIn(list))).go();
      await (_db.update(_db.memories)..where((m) => m.id.isIn(list))).write(
        MemoriesCompanion(
          deleted: const Value(true),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );
    });
  }

  /// Rename.
  Future<void> rename(int id, String title) =>
      (_db.update(_db.memories)..where((m) => m.id.equals(id))).write(
        MemoriesCompanion(customTitle: Value(title.trim())),
      );
}

/// Multi-year memories first (most pictures first), then newest first.
int compareMemories(StoredMemory a, StoredMemory b) {
  bool multi(MemoryKind k) =>
      k == MemoryKind.pastTimes ||
      k == MemoryKind.groupPhotos ||
      k == MemoryKind.person;
  final ma = multi(a.kind);
  final mb = multi(b.kind);
  if (ma != mb) return ma ? -1 : 1;
  if (ma) return b.candidates.compareTo(a.candidates);
  return b.endMs.compareTo(a.endMs);
}
