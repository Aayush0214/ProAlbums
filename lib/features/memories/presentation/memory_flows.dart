import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proalbums/features/memories/data/memory_repository.dart';
import 'package:proalbums/features/memories/presentation/memory_providers.dart';
import 'package:proalbums/shared/widgets/app_snack_bar.dart';
import 'package:proalbums/shared/widgets/confirm_dialog.dart';
import 'package:proalbums/shared/widgets/text_input_dialog.dart';

/// Tap on a memory: plays its video (phase 4).
void openMemory(BuildContext context, StoredMemory memory) =>
    showComingSoon(context, 'Memory video');

/// ⋮ > View Gallery: the memory's pictures (phase 3).
void viewMemoryGallery(BuildContext context, StoredMemory memory) =>
    showComingSoon(context, 'View Gallery');

/// ⋮ > Rename.
Future<void> renameMemory(
  BuildContext context,
  WidgetRef ref,
  StoredMemory memory,
) async {
  final name = await showTextInputDialog(
    context,
    title: 'Rename',
    initial: memory.title,
  );
  if (name == null || name == memory.title) return;
  await ref.read(memoryStoreProvider).rename(memory.id, name);
  ref.read(memoryScanProvider.notifier).changed();
}

/// ⋮ > Delete memories / Memories page > Delete: the memories go, their
/// pictures stay. true = deleted.
Future<bool> deleteMemories(
  BuildContext context,
  WidgetRef ref,
  List<int> ids,
) async {
  if (ids.isEmpty) return false;
  final ok = await showConfirmDialog(
    context,
    title: ids.length == 1
        ? 'Permanently delete this memory?'
        : 'Permanently delete ${ids.length} memories?',
    confirmLabel: 'Permanently delete',
  );
  if (ok != true) return false;
  await ref.read(memoryStoreProvider).delete(ids);
  ref.read(memoryScanProvider.notifier).changed();
  return true;
}
