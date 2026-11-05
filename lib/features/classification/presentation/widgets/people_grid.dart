import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/classification/data/face_repository.dart';
import 'package:proalbums/features/classification/presentation/widgets/face_avatar.dart';
import 'package:proalbums/features/gallery/presentation/providers/media_selection.dart';
import 'package:proalbums/features/gallery/presentation/widgets/selection_checkbox.dart';

/// People as big circles, 3 per row (no zoom), the name under a named one;
/// while [selected] is not null each gets a checkbox.
class PeopleGridSliver extends StatelessWidget {
  const PeopleGridSliver({
    required this.people,
    required this.onTap,
    this.selected,
    this.onLongPress,
    super.key,
  });

  final List<PersonSummary> people;

  /// null = not selecting.
  final Set<int>? selected;
  final ValueChanged<PersonSummary> onTap;
  final ValueChanged<PersonSummary>? onLongPress;

  static const double _side = 20;
  static const double _gap = 18;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final cell = (width - _side * 2 - _gap * 2) / 3;
    final named = people.any((p) => p.name != null);

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(_side, 16, _side, 24),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: _gap,
          mainAxisSpacing: named ? 8 : _gap + 8,
          mainAxisExtent: cell + (named ? 32 : 0),
        ),
        delegate: SliverChildBuilderDelegate(childCount: people.length, (
          context,
          index,
        ) {
          final person = people[index];
          final checked = selected?.contains(person.id);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTap(person),
            onLongPress: onLongPress == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onLongPress!(person);
                  },
            child: Column(
              children: [
                Stack(
                  children: [
                    FaceAvatar(face: person.cover, diameter: cell),
                    if (checked != null)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: SelectionCheckbox(
                          state: checked
                              ? SelectionState.all
                              : SelectionState.none,
                          onPhoto: true,
                        ),
                      ),
                  ],
                ),
                if (person.name case final name?)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.titleSmall,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

/// One button of [PeopleActionBar]; null [onPressed] = greyed.
typedef PeopleBarAction = ({
  IconData icon,
  String label,
  VoidCallback? onPressed,
});

/// The bottom bar of People's select mode (Hide, Merge).
class PeopleActionBar extends StatelessWidget {
  const PeopleActionBar({required this.actions, super.key});

  final List<PeopleBarAction> actions;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 3,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (final action in actions)
                Expanded(
                  child: InkWell(
                    onTap: action.onPressed,
                    borderRadius: BorderRadius.circular(12),
                    child: Builder(
                      builder: (context) {
                        final color = action.onPressed == null
                            ? Theme.of(context).disabledColor
                            : scheme.onSurface;
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(action.icon, size: 22, color: color),
                            const SizedBox(height: 4),
                            Text(
                              action.label,
                              style: context.textTheme.labelMedium?.copyWith(
                                color: color,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "N images or videos in total" under "N selected".
String picturesInTotal(Iterable<PersonSummary> people) {
  final total = people.fold<int>(0, (sum, p) => sum + p.pictures);
  return '$total images or videos in total';
}
