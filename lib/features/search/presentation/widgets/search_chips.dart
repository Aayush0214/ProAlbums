import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/search/domain/search_rules.dart';

/// A result page's filter chips side by side (years, then labels). Any
/// number can be chosen; a chosen chip is filled and shows ✕.
class SearchChipsRow extends StatelessWidget {
  const SearchChipsRow({
    required this.chips,
    required this.chosen,
    required this.onToggle,
    super.key,
  });

  final List<SearchChip> chips;
  final Set<SearchChip> chosen;
  final ValueChanged<SearchChip> onToggle;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 44,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: chips.length,
      separatorBuilder: (_, _) => const SizedBox(width: 10),
      itemBuilder: (context, i) => _Chip(
        chip: chips[i],
        selected: chosen.contains(chips[i]),
        onTap: () => onToggle(chips[i]),
      ),
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.chip,
    required this.selected,
    required this.onTap,
  });

  final SearchChip chip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final foreground = selected ? scheme.onPrimary : scheme.primary;
    return Material(
      color: selected ? scheme.primary : scheme.surfaceContainerHigh,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.only(left: 18, right: selected ? 12 : 18),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                chip.value,
                style: context.textTheme.bodyLarge?.copyWith(color: foreground),
              ),
              if (selected) ...[
                const SizedBox(width: 6),
                Icon(LucideIcons.x, size: 16, color: foreground),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
