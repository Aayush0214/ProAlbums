import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/app/router/app_routes.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/cleanup/domain/cleanup_rules.dart';
import 'package:proalbums/features/cleanup/presentation/cleanup_page.dart';
import 'package:proalbums/features/cleanup/presentation/cleanup_providers.dart';
import 'package:proalbums/features/gallery/presentation/images/media_thumbnail_image.dart';
import 'package:proalbums/features/gallery/presentation/widgets/media_thumbnail.dart';
import 'package:proalbums/shared/widgets/app_back_button.dart';

/// What the preview page needs: the kind, where to start, and the shared
/// selection (so a pick there shows here too).
typedef CleanupPreviewRequest = ({
  CleanupKind kind,
  String startId,
  ValueNotifier<Set<String>> selection,
});

/// "Duplicate images" / "Similar images" (like the system gallery):
/// "84 sets in total (721 MB)." + Smart recommendation; each set with its
/// date, size and a checkbox (all / some / none), its pictures with their
/// size and a checkbox; tap = preview. Delete (N files, size) at the bottom.
class CleanupGroupsPage extends ConsumerStatefulWidget {
  const CleanupGroupsPage({required this.kind, super.key});

  final CleanupKind kind;

  @override
  ConsumerState<CleanupGroupsPage> createState() => _CleanupGroupsPageState();
}

class _CleanupGroupsPageState extends ConsumerState<CleanupGroupsPage> {
  final ValueNotifier<Set<String>> _selection = ValueNotifier(const {});
  final Set<int> _collapsed = {};

  @override
  void initState() {
    super.initState();
    _selection.addListener(_changed);
  }

  @override
  void dispose() {
    _selection
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Set<String> get _selected => _selection.value;

  void _set(Set<String> ids) => _selection.value = ids;

  /// Smart recommendation: everything but the best picture of each set.
  Set<String> _smart(List<CleanupGroup> groups) => {
    for (final group in groups)
      for (final image in group)
        if (image.id != bestOf(group).id) image.id,
  };

  Future<void> _delete(List<CleanupGroup> groups) async {
    final images = [
      for (final group in groups)
        for (final image in group)
          if (_selected.contains(image.id)) image,
    ];
    if (images.isEmpty) return;
    final done = await deleteCleanupImages(context, ref, images);
    if (done && mounted) _set(const {});
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(
      cleanupScanProvider.select((s) => s.groupsOf(widget.kind)),
    );
    // Selected pictures that are gone (deleted elsewhere) do not count.
    final present = {
      for (final group in groups)
        for (final image in group) image.id,
    };
    final selected = _selected.where(present.contains).toSet();
    final selectedImages = [
      for (final group in groups)
        for (final image in group)
          if (selected.contains(image.id)) image,
    ];
    final selectedBytes = selectedImages.fold<int>(0, (s, i) => s + i.size);
    final totalBytes = groups.fold<int>(
      0,
      (sum, group) => sum + group.fold<int>(0, (s, image) => s + image.size),
    );
    final smart = _smart(groups);
    final isSmart =
        groups.isNotEmpty &&
        selected.length == smart.length &&
        selected.containsAll(smart);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(widget.kind.title),
      ),
      body: groups.isEmpty
          ? const CleanupEmpty()
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: groups.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _Header(
                    sets: groups.length,
                    bytes: totalBytes,
                    smart: isSmart,
                    onSmart: (on) => _set(on ? smart : const {}),
                  );
                }
                final group = groups[index - 1];
                return _GroupView(
                  group: group,
                  kind: widget.kind,
                  collapsed: _collapsed.contains(index),
                  selected: selected,
                  onCollapse: () => setState(() {
                    if (!_collapsed.remove(index)) _collapsed.add(index);
                  }),
                  onGroupCheck: () {
                    final ids = {for (final image in group) image.id};
                    final all = selected.containsAll(ids);
                    _set(
                      all ? (selected.difference(ids)) : {...selected, ...ids},
                    );
                  },
                  onCheck: (id) => _set(
                    selected.contains(id)
                        ? (selected.difference({id}))
                        : {...selected, id},
                  ),
                  onOpen: (id) => unawaited(
                    context.push<void>(
                      AppRoutes.cleanupPreview,
                      extra: (
                        kind: widget.kind,
                        startId: id,
                        selection: _selection,
                      ),
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: groups.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(48, 8, 48, 12),
                child: SizedBox(
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(shape: const StadiumBorder()),
                    onPressed: selectedImages.isEmpty
                        ? null
                        : () => _delete(groups),
                    child: Text(
                      selectedImages.isEmpty
                          ? 'Delete'
                          : 'Delete (${cleanupFilesLabel(selectedImages.length)}, '
                                '${cleanupSize(selectedBytes)})',
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

/// "1 file" / "72 files".
String cleanupFilesLabel(int count) => count == 1 ? '1 file' : '$count files';

class _Header extends StatelessWidget {
  const _Header({
    required this.sets,
    required this.bytes,
    required this.smart,
    required this.onSmart,
  });

  final int sets;
  final int bytes;
  final bool smart;
  final ValueChanged<bool> onSmart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$sets ${sets == 1 ? 'set' : 'sets'} in total '
              '(${cleanupSize(bytes)}).',
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ),
          Text(
            'Smart\nrecommendation',
            textAlign: TextAlign.end,
            style: context.textTheme.bodyMedium,
          ),
          Checkbox(value: smart, onChanged: (on) => onSmart(on ?? false)),
        ],
      ),
    );
  }
}

class _GroupView extends ConsumerWidget {
  const _GroupView({
    required this.group,
    required this.kind,
    required this.collapsed,
    required this.selected,
    required this.onCollapse,
    required this.onGroupCheck,
    required this.onCheck,
    required this.onOpen,
  });

  final CleanupGroup group;
  final CleanupKind kind;
  final bool collapsed;
  final Set<String> selected;
  final VoidCallback onCollapse;
  final VoidCallback onGroupCheck;
  final ValueChanged<String> onCheck;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taken = DateTime.fromMillisecondsSinceEpoch(group.first.takenMs);
    final date = taken.year == DateTime.now().year
        ? DateFormat.MMMMd().format(taken)
        : DateFormat.yMMMMd().format(taken);
    final bytes = group.fold<int>(0, (s, i) => s + i.size);
    final count = group.where((i) => selected.contains(i.id)).length;
    final load = thumbnailLoader(ref);
    final tile = (MediaQuery.sizeOf(context).width - 9) / 4;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onCollapse,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                Icon(
                  collapsed
                      ? LucideIcons.chevronRight
                      : LucideIcons.chevronDown,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(date, style: context.textTheme.titleMedium),
                      if (kind == CleanupKind.duplicates && !collapsed)
                        Text(
                          'Keep 1 copy per duplicate group',
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  cleanupSize(bytes),
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
                Checkbox(
                  tristate: true,
                  value: count == 0
                      ? false
                      : count == group.length
                      ? true
                      : null,
                  onChanged: (_) => onGroupCheck(),
                ),
              ],
            ),
          ),
        ),
        if (!collapsed)
          Wrap(
            spacing: 3,
            runSpacing: 3,
            children: [
              for (final image in group)
                SizedBox.square(
                  dimension: tile,
                  child: GestureDetector(
                    onTap: () => onOpen(image.id),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image(
                          image: MediaThumbnailImage(
                            id: image.id,
                            size: 256,
                            load: load,
                          ),
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        ),
                        Positioned(
                          right: 6,
                          bottom: 4,
                          child: Text(
                            cleanupSize(image.size),
                            style: context.textTheme.labelMedium?.copyWith(
                              color: AppColors.mediaBadgeText,
                              shadows: const [
                                Shadow(
                                  blurRadius: 4,
                                  color: AppColors.mediaBadgeFill,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Checkbox(
                            value: selected.contains(image.id),
                            onChanged: (_) => onCheck(image.id),
                            side: const BorderSide(
                              color: AppColors.mediaBadgeText,
                              width: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
