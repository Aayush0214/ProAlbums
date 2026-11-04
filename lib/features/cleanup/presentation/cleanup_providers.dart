import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:proalbums/core/database/database_providers.dart';
import 'package:proalbums/core/logging/app_logger.dart';
import 'package:proalbums/features/cleanup/data/cleanup_repository.dart';
import 'package:proalbums/features/cleanup/domain/cleanup_rules.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/providers/media_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'cleanup_providers.g.dart';

@Riverpod(keepAlive: true)
CleanupScanner cleanupScanner(Ref ref) => const MethodChannelCleanupScanner();

@Riverpod(keepAlive: true)
CleanupFingerprintStore cleanupFingerprintStore(Ref ref) =>
    CleanupFingerprintStore(ref.watch(appDatabaseProvider));

const String _enabledKey = 'cleanup_suggestions_enabled';

/// Settings > "Cleanup suggestions" (on by default). Off: nothing is
/// scanned and the Albums row is hidden.
@Riverpod(keepAlive: true)
class CleanupEnabled extends _$CleanupEnabled {
  @override
  Future<bool> build() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_enabledKey) ?? true;
    } on Object {
      return true;
    }
  }

  Future<void> save({required bool enabled}) async {
    state = AsyncData(enabled);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, enabled);
    } on Object {
      // Back to the default next time.
    }
  }
}

/// Where the scan is, and what it found.
@immutable
final class CleanupState {
  const CleanupState({
    this.ready = false,
    this.scanning = false,
    this.done = 0,
    this.total = 0,
    this.groups = const {},
  });

  /// A scan has finished at least once (the groups are real).
  final bool ready;
  final bool scanning;

  /// Pictures looked at / to look at in this scan.
  final int done;
  final int total;
  final Map<CleanupKind, List<CleanupGroup>> groups;

  List<CleanupGroup> groupsOf(CleanupKind kind) => groups[kind] ?? const [];

  /// Different pictures in all the sets (the Albums row's number).
  int get count => {
    for (final sets in groups.values)
      for (final group in sets)
        for (final image in group) image.id,
  }.length;

  CleanupState copyWith({
    bool? ready,
    bool? scanning,
    int? done,
    int? total,
    Map<CleanupKind, List<CleanupGroup>>? groups,
  }) => CleanupState(
    ready: ready ?? this.ready,
    scanning: scanning ?? this.scanning,
    done: done ?? this.done,
    total: total ?? this.total,
    groups: groups ?? this.groups,
  );
}

/// Cleanup suggestions' scan. Started by the Albums row; looks at each
/// picture once (fingerprints remembered in Drift, again only when the file
/// changed), reads file hashes only for exact-duplicate candidates, and runs
/// again (quietly) when the library changes.
@Riverpod(keepAlive: true)
class CleanupScan extends _$CleanupScan {
  bool _running = false;
  bool _again = false;
  bool _started = false;
  Timer? _changed;

  static const int _printBatch = 48;
  static const int _hashBatch = 24;

  @override
  CleanupState build() {
    ref
      ..listen(mediaLibraryChangesProvider, (_, _) {
        if (!_started) return;
        _changed?.cancel();
        _changed = Timer(const Duration(seconds: 2), () => unawaited(scan()));
      })
      ..listen(cleanupEnabledProvider, (_, next) {
        if (next.value ?? false) {
          if (_started) unawaited(scan());
        } else {
          state = const CleanupState(ready: true);
        }
      })
      ..onDispose(() => _changed?.cancel());
    return const CleanupState();
  }

  /// First call starts the scan; later calls do nothing until the library
  /// changes (or [scan] is called).
  void ensureStarted() {
    if (_started) return;
    _started = true;
    unawaited(scan());
  }

  Future<void> scan() async {
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      do {
        _again = false;
        if (!await ref.read(cleanupEnabledProvider.future)) {
          state = const CleanupState(ready: true);
          return;
        }
        await _scanOnce();
      } while (_again && ref.mounted);
    } on Object catch (error, stackTrace) {
      AppLogger.e('Cleanup scan failed', error: error, stackTrace: stackTrace);
      if (ref.mounted) state = state.copyWith(scanning: false, ready: true);
    } finally {
      _running = false;
    }
  }

  Future<void> _scanOnce() async {
    final scanner = ref.read(cleanupScannerProvider);
    final store = ref.read(cleanupFingerprintStoreProvider);
    final listed = await scanner.listImages();
    final stored = await store.all();
    if (!ref.mounted) return;

    final present = {for (final image in listed) image.id};
    await store.forget(stored.keys.where((id) => !present.contains(id)));

    final modified = {for (final image in listed) image.id: image.modified};
    final todo = [
      for (final image in listed)
        if (stored[image.id]?.modified != image.modified) image.id,
    ];
    state = state.copyWith(
      scanning: todo.isNotEmpty,
      done: 0,
      total: todo.length,
    );

    final prints = <String, StoredFingerprint>{...stored};
    for (var i = 0; i < todo.length; i += _printBatch) {
      final batch = todo.sublist(i, (i + _printBatch).clamp(0, todo.length));
      final found = await scanner.fingerprints(batch);
      await store.saveFingerprints(found, modified);
      for (final print in found) {
        prints[print.id] = (
          modified: modified[print.id] ?? 0,
          dhash: print.dhash,
          sharpness: print.sharpness,
          sha1: null,
        );
      }
      if (!ref.mounted) return;
      state = state.copyWith(done: i + batch.length);
    }

    var images = [
      for (final image in listed)
        CleanupImage(
          id: image.id,
          size: image.size,
          width: image.width,
          height: image.height,
          takenMs: image.takenMs,
          dhash: prints[image.id]?.dhash,
          sharpness: prints[image.id]?.sharpness ?? 0,
          sha1: prints[image.id]?.sha1,
        ),
    ];

    // File hashes only where an exact copy is possible.
    final needHash = [
      for (final image in duplicateCandidates(images))
        if (image.sha1 == null && prints.containsKey(image.id)) image.id,
    ];
    final hashes = <String, String>{};
    for (var i = 0; i < needHash.length; i += _hashBatch) {
      final batch = needHash.sublist(
        i,
        (i + _hashBatch).clamp(0, needHash.length),
      );
      hashes.addAll(await scanner.contentHashes(batch));
      if (!ref.mounted) return;
    }
    await store.saveHashes(hashes);
    if (hashes.isNotEmpty) {
      images = [
        for (final image in images)
          hashes.containsKey(image.id)
              ? CleanupImage(
                  id: image.id,
                  size: image.size,
                  width: image.width,
                  height: image.height,
                  takenMs: image.takenMs,
                  dhash: image.dhash,
                  sharpness: image.sharpness,
                  sha1: hashes[image.id],
                )
              : image,
      ];
    }

    if (!ref.mounted) return;
    state = CleanupState(
      ready: true,
      groups: {
        CleanupKind.duplicates: duplicateGroups(images),
        CleanupKind.similar: similarGroups(images),
      },
    );
  }

  /// Pictures were deleted: out of every set at once (sets of one go away),
  /// before the next scan confirms it.
  void removeIds(Set<String> ids) {
    state = state.copyWith(
      groups: {
        for (final entry in state.groups.entries)
          entry.key: [
            for (final group in entry.value)
              if (group.where((i) => !ids.contains(i.id)).length > 1)
                [
                  for (final image in group)
                    if (!ids.contains(image.id)) image,
                ],
          ],
      },
    );
  }
}

/// A Cleanup picture as a gallery item (thumbnail, viewer, delete).
MediaItem cleanupMediaItem(CleanupImage image) => MediaItem(
  id: image.id,
  type: MediaType.image,
  createdAt: DateTime.fromMillisecondsSinceEpoch(image.takenMs),
  width: image.width,
  height: image.height,
);
