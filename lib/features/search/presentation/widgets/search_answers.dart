import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/gallery/presentation/actions/media_actions.dart';
import 'package:proalbums/features/gallery/presentation/providers/media_selection.dart';
import 'package:proalbums/features/gallery/presentation/viewer/open_media_viewer.dart';
import 'package:proalbums/features/gallery/presentation/widgets/media_thumbnail.dart';
import 'package:proalbums/features/search/domain/search_rules.dart';
import 'package:proalbums/features/search/presentation/search_providers.dart';
import 'package:proalbums/features/search/presentation/widgets/search_home.dart';

/// The answers for a query: one line per answer (icon, name, count), "N
/// images · View all" with 2 rows of pictures, then the answers again as
/// cards by kind (Location, Types…).
class SearchAnswers extends ConsumerWidget {
  const SearchAnswers({required this.query, required this.onOpen, super.key});

  final String query;

  /// Something was opened: remember this text as a recent search.
  final ValueChanged<String> onOpen;

  /// Lines at the top (the cards below list every answer).
  static const int _maxLines = 8;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(searchResultsProvider(query)).value;
    if (groups == null) return const SizedBox.shrink();
    if (groups.isEmpty) {
      return Center(
        child: Text(
          'No results',
          style: context.textTheme.bodyLarge?.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
      );
    }
    final all = SearchTarget(
      kind: SearchTargetKind.all,
      title: query,
      query: query,
    );
    final count = ref.watch(searchTargetIdsProvider(all)).value?.length ?? 0;

    void open(SearchGroup group) {
      onOpen(_remembered(group, query));
      openSearchResult(
        context,
        SearchTarget(
          kind: SearchTargetKind.answer,
          key: group.key,
          title: group.title,
          query: query,
        ),
      );
    }

    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverList.list(
          children: [
            for (final group in groups.take(_maxLines))
              _AnswerLine(group: group, onTap: () => open(group)),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 4, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${NumberFormat.decimalPattern().format(count)} '
                    '${count == 1 ? 'image' : 'images'}',
                    style: context.textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    onOpen(query);
                    openSearchResult(context, all);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: context.colors.textSecondary,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('View all'),
                      SizedBox(width: 2),
                      Icon(LucideIcons.chevronRight, size: 18),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: _Preview(target: all, onOpen: () => onOpen(query)),
        ),
        for (final kind in SearchKind.values)
          if (groups.where((g) => g.kind == kind).toList() case final list
              when list.isNotEmpty)
            SliverToBoxAdapter(
              child: _KindCard(kind: kind, groups: list, onTap: open),
            ),
        SliverToBoxAdapter(
          child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 24),
        ),
      ],
    );
  }
}

/// What goes into Recent searches when an answer is opened: a name (a
/// place, a person, a type, an album), else what was typed.
String _remembered(SearchGroup group, String query) => switch (group.kind) {
  SearchKind.person ||
  SearchKind.place ||
  SearchKind.type ||
  SearchKind.album => group.title,
  SearchKind.text || SearchKind.fileName || SearchKind.date => query,
};

IconData _iconOf(SearchKind kind) => switch (kind) {
  SearchKind.person => LucideIcons.user,
  SearchKind.place => LucideIcons.mapPin,
  SearchKind.type => LucideIcons.sparkles,
  SearchKind.album => LucideIcons.folder,
  SearchKind.text => LucideIcons.scanText,
  SearchKind.fileName => LucideIcons.fileImage,
  SearchKind.date => LucideIcons.calendar,
};

/// The top list's wording of an answer.
String _lineText(SearchGroup group) => switch (group.kind) {
  SearchKind.text => 'Images containing text "${group.title}"',
  SearchKind.fileName => 'File names containing "${group.title}"',
  _ => group.title,
};

String _sectionTitle(SearchKind kind) => switch (kind) {
  SearchKind.person => 'People',
  SearchKind.place => 'Location',
  SearchKind.type => 'Types',
  SearchKind.album => 'Albums',
  SearchKind.text => 'Text recognition',
  SearchKind.fileName => 'File names',
  SearchKind.date => 'Date',
};

class _AnswerLine extends StatelessWidget {
  const _AnswerLine({required this.group, required this.onTap});

  final SearchGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Icon(_iconOf(group.kind), size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(_lineText(group), style: context.textTheme.bodyLarge),
          ),
          const SizedBox(width: 12),
          Text(
            NumberFormat.decimalPattern().format(group.ids.length),
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );
}

/// The first 2 rows of every answer's pictures; a tap opens the viewer on
/// all of them.
class _Preview extends ConsumerWidget {
  const _Preview({required this.target, required this.onOpen});

  final SearchTarget target;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsProvider = searchTargetItemsProvider(target);
    final items = ref.watch(itemsProvider);
    final shown = items.take(SearchRules.previewCount).toList();
    final side = MediaQuery.sizeOf(context).width / searchGridColumns;
    return MediaScope(
      id: '${target.scopeId}:preview',
      mediaContext: MediaContext.search,
      items: itemsProvider,
      child: Builder(
        builder: (context) => Wrap(
          spacing: 1,
          runSpacing: 1,
          children: [
            for (final item in shown)
              GestureDetector(
                onTap: () {
                  onOpen();
                  openMediaViewer(context, ref, id: item.id);
                },
                child: SizedBox.square(
                  dimension: side - 1,
                  child: MediaThumbnail(item: item, compactBadge: true),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One kind's answers as a card (thumbnail, name, count, >).
class _KindCard extends StatelessWidget {
  const _KindCard({
    required this.kind,
    required this.groups,
    required this.onTap,
  });

  final SearchKind kind;
  final List<SearchGroup> groups;
  final ValueChanged<SearchGroup> onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            _sectionTitle(kind),
            style: context.textTheme.titleSmall?.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: ColoredBox(
            color: context.colorScheme.surfaceContainerHigh,
            child: Column(
              children: [
                for (final (i, group) in groups.indexed) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      indent: 84,
                      color: context.colors.dividerSubtle,
                    ),
                  _CardRow(group: group, onTap: () => onTap(group)),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _CardRow extends ConsumerWidget {
  const _CardRow({required this.group, required this.onTap});

  final SearchGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(searchIndexProvider).value;
    final cover = index?.byId[group.ids.first];
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 52,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: cover == null
                    ? const SizedBox.shrink()
                    : MediaThumbnail(
                        item: searchMediaItem(cover),
                        size: 128,
                        compactBadge: true,
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                group.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodyLarge,
              ),
            ),
            Text(
              NumberFormat.decimalPattern().format(group.ids.length),
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              LucideIcons.chevronRight,
              size: 20,
              color: context.colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
