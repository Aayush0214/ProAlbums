import 'package:flutter/material.dart';
import 'package:proalbums/features/gallery/presentation/providers/photos_selection_controller.dart';

/// The rounded-square checkbox used on photos, date headers and the app bar.
/// [SelectionState.partial] shows a "minus" (some photos of the day).
class SelectionCheckbox extends StatelessWidget {
  const SelectionCheckbox({
    required this.state,
    this.size = 22,
    this.onPhoto = false,
    super.key,
  });

  final SelectionState state;
  final double size;

  /// On top of a photo the empty box is white-outlined with a dark tint, so it
  /// is visible on any picture.
  final bool onPhoto;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filled = state != SelectionState.none;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.2),
        color: filled
            ? scheme.primary
            : (onPhoto ? Colors.black26 : Colors.transparent),
        border: filled
            ? null
            : Border.all(
                color: onPhoto ? Colors.white : scheme.onSurfaceVariant,
                width: size > 16 ? 1.6 : 1.2,
              ),
      ),
      child: filled
          ? Icon(
              state == SelectionState.partial
                  ? Icons.remove_rounded
                  : Icons.check_rounded,
              size: size * 0.75,
              color: scheme.onPrimary,
            )
          : null,
    );
  }
}
