import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/albums/presentation/widgets/album_selection_widgets.dart';
import 'package:proalbums/features/classification/presentation/widgets/people_grid.dart';
import 'package:proalbums/features/memories/data/memory_repository.dart';
import 'package:proalbums/features/memories/presentation/memory_flows.dart';
import 'package:proalbums/features/memories/presentation/memory_providers.dart';
import 'package:proalbums/features/memories/presentation/widgets/memory_cards.dart';
import 'package:proalbums/shared/widgets/app_back_button.dart';
import 'package:proalbums/shared/widgets/collapsing_sliver_app_bar.dart';

/// For You > Memories > More: every memory as a big card (⋮ on each).
/// Select (icon or long press) → check boxes + Delete (the memories go,
/// the pictures stay).
class MemoriesPage extends ConsumerStatefulWidget {
  const MemoriesPage({super.key});

  @override
  ConsumerState<MemoriesPage> createState() => _MemoriesPageState();
}

class _MemoriesPageState extends ConsumerState<MemoriesPage> {
  /// null = not selecting.
  Set<int>? _selected;

  void _toggle(int id) => setState(() {
    final selected = {...?_selected};
    if (!selected.remove(id)) selected.add(id);
    _selected = selected;
  });

  Future<void> _delete() async {
    final ids = _selected?.toList() ?? const <int>[];
    if (await deleteMemories(context, ref, ids) && mounted) {
      setState(() => _selected = null);
    }
  }

  void _onMenu(StoredMemory memory, MemoryMenuAction action) {
    switch (action) {
      case MemoryMenuAction.viewGallery:
        viewMemoryGallery(context, memory);
      case MemoryMenuAction.rename:
        unawaited(renameMemory(context, ref, memory));
      case MemoryMenuAction.delete:
        unawaited(deleteMemories(context, ref, [memory.id]));
    }
  }

  @override
  Widget build(BuildContext context) {
    final memories = ref.watch(memoryListProvider).value ?? const [];
    final selected = _selected;
    return PopScope(
      canPop: selected == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _selected = null);
      },
      child: Scaffold(
        bottomNavigationBar: selected == null
            ? null
            : PeopleActionBar(
                actions: [
                  (
                    icon: LucideIcons.trash2,
                    label: 'Delete',
                    onPressed: selected.isEmpty ? null : _delete,
                    destructive: true,
                  ),
                ],
              ),
        body: CustomScrollView(
          slivers: [
            if (selected != null)
              AlbumSelectionHeader(
                selectedCount: selected.length,
                itemCount: memories.length,
                onSelectAllToggle: () => setState(
                  () => _selected = selected.length == memories.length
                      ? {}
                      : {for (final m in memories) m.id},
                ),
                onClose: () => setState(() => _selected = null),
              )
            else
              CollapsingSliverAppBar(
                title: 'Memories',
                leading: const AppBackButton(),
                actions: [
                  if (memories.isNotEmpty)
                    IconButton(
                      tooltip: 'Select',
                      icon: const Icon(LucideIcons.squareCheck),
                      onPressed: () => setState(() => _selected = {}),
                    ),
                ],
              ),
            if (memories.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    'No memories yet',
                    style: context.textTheme.bodyLarge?.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  MediaQuery.paddingOf(context).bottom + 24,
                ),
                sliver: SliverList.separated(
                  itemCount: memories.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 20),
                  itemBuilder: (context, i) {
                    final memory = memories[i];
                    return MemoryCard(
                      memory: memory,
                      big: true,
                      selected: selected?.contains(memory.id),
                      onTap: selected != null
                          ? () => _toggle(memory.id)
                          : () => openMemory(context, memory),
                      onLongPress: selected != null
                          ? null
                          : () => setState(() => _selected = {memory.id}),
                      onMenu: (action) => _onMenu(memory, action),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
