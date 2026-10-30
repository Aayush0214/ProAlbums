import 'package:flutter/material.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/gallery/domain/entities/media_page_request.dart';

/// "Browsing order" picker: a FLOATING card (not attached to the screen
/// bottom), title in the middle, two options and a Cancel button.
Future<void> showBrowsingOrderSheet(
  BuildContext context, {
  required MediaSortOrder current,
  required ValueChanged<MediaSortOrder> onSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    // The card paints its own background, the sheet itself is invisible.
    backgroundColor: Colors.transparent,
    elevation: 0,
    showDragHandle: false,
    builder: (sheetContext) => _BrowsingOrderCard(
      current: current,
      onSelected: (order) {
        Navigator.of(sheetContext).pop();
        onSelected(order);
      },
      onCancel: () => Navigator.of(sheetContext).pop(),
    ),
  );
}

class _BrowsingOrderCard extends StatelessWidget {
  const _BrowsingOrderCard({
    required this.current,
    required this.onSelected,
    required this.onCancel,
  });

  final MediaSortOrder current;
  final ValueChanged<MediaSortOrder> onSelected;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SafeArea(
      child: Padding(
        // The gap around the card is what makes it "float".
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 24),
              Text(
                'Browsing order',
                textAlign: TextAlign.center,
                style: context.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _OrderOption(
                label: 'Newest at the top',
                selected: current == MediaSortOrder.newestFirst,
                onTap: () => onSelected(MediaSortOrder.newestFirst),
              ),
              Divider(indent: 24, endIndent: 24, color: colors.dividerSubtle),
              _OrderOption(
                label: 'Newest at the bottom',
                selected: current == MediaSortOrder.oldestFirst,
                onTap: () => onSelected(MediaSortOrder.oldestFirst),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: onCancel, child: const Text('Cancel')),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderOption extends StatelessWidget {
  const _OrderOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Expanded(child: Text(label, style: context.textTheme.bodyLarge)),
              _RadioDot(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

/// Drawn by hand (ring + dot) so we do not depend on the Radio widget API.
class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = selected ? colors.activeAccent : colors.textSecondary;

    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
            )
          : null,
    );
  }
}
