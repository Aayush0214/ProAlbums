import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/classification/data/face_repository.dart';
import 'package:proalbums/features/classification/domain/face_rules.dart';
import 'package:proalbums/features/classification/presentation/classification_providers.dart';
import 'package:proalbums/features/classification/presentation/people_providers.dart';
import 'package:proalbums/features/classification/presentation/widgets/face_avatar.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/shared/widgets/app_snack_bar.dart';
import 'package:proalbums/shared/widgets/confirm_dialog.dart';

/// "Add name" (like the system gallery): the name, or null when cancelled.
/// An empty name removes the name.
Future<String?> showAddNameDialog(BuildContext context, {String? initial}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _AddNameDialog(initial: initial ?? ''),
    );

class _AddNameDialog extends StatefulWidget {
  const _AddNameDialog({required this.initial});

  final String initial;

  @override
  State<_AddNameDialog> createState() => _AddNameDialogState();
}

class _AddNameDialogState extends State<_AddNameDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.initial)
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.initial.length,
        );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _ok() => Navigator.of(context).pop(_name.text.trim());

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add name',
              textAlign: TextAlign.center,
              style: context.textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _name,
              builder: (context, value, _) => TextField(
                controller: _name,
                autofocus: true,
                maxLength: 40,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _ok(),
                decoration: InputDecoration(
                  hintText: 'Enter content',
                  counterText: '',
                  suffixIcon: value.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(LucideIcons.x, size: 20),
                          onPressed: _name.clear,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(shape: const StadiumBorder()),
                onPressed: _ok,
                child: const Text('OK'),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Add name" on a person, saved. True when it changed.
Future<bool> addPersonName(
  BuildContext context,
  WidgetRef ref,
  PersonSummary person,
) async {
  final name = await showAddNameDialog(context, initial: person.name);
  if (name == null || name == (person.name ?? '')) return false;
  await ref.read(faceStoreProvider).rename(person.id, name);
  ref.read(faceScanProvider.notifier).peopleChanged();
  return true;
}

/// Who the others are merged INTO: a named person first, then the one in
/// the most pictures.
PersonSummary mergeTarget(List<PersonSummary> people) => people.reduce((a, b) {
  if ((a.name != null) != (b.name != null)) return a.name != null ? a : b;
  return a.pictures >= b.pictures ? a : b;
});

/// "Merge N people into the same person?" (others > target), then merges.
/// True when merged.
Future<bool> mergePeople(
  BuildContext context,
  WidgetRef ref,
  List<PersonSummary> people, {
  PersonSummary? into,
}) async {
  if (people.length < 2) return false;
  final target = into ?? mergeTarget(people);
  final others = [
    for (final p in people)
      if (p.id != target.id) p,
  ];
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Merge ${people.length} people into the same person?',
              textAlign: TextAlign.center,
              style: context.textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final p in others.take(3))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: FaceAvatar(
                      face: p.cover,
                      diameter: others.length > 1 ? 48 : 64,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Icon(
                    LucideIcons.chevronRight,
                    color: context.colors.textSecondary,
                  ),
                ),
                FaceAvatar(face: target.cover, diameter: 64),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Merging cannot be undone.',
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(shape: const StadiumBorder()),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Merge'),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    ),
  );
  if (ok != true) return false;
  await ref.read(faceStoreProvider).merge([
    for (final p in others) p.id,
  ], into: target.id);
  ref.read(faceScanProvider.notifier).peopleChanged();
  return true;
}

/// Hide (false) / "+" add (true) people on the People page.
Future<void> showPeople(
  WidgetRef ref,
  Iterable<int> personIds, {
  required bool shown,
}) async {
  await ref.read(faceStoreProvider).setShown(personIds, shown: shown);
  ref.read(faceScanProvider.notifier).peopleChanged();
}

/// "Set as cover" (one picture of the person shown in [albumId]).
Future<bool> setPersonCover(
  BuildContext context,
  WidgetRef ref,
  String? albumId,
  MediaItem item,
) async {
  final personId = personIdOfAlbum(albumId);
  if (personId == null) return false;
  final toast = AppToast.of(context);
  final person = ref.read(personProvider(personId));
  if (person?.cover.mediaId == item.id) {
    toast.show('Already set as cover');
    return true;
  }
  final faces = await ref.read(personFacesProvider(personId).future);
  final face = faces.where((f) => f.mediaId == item.id).firstOrNull;
  if (face == null) return false;
  await ref.read(faceStoreProvider).setCover(personId, face.id);
  ref.read(faceScanProvider.notifier).peopleChanged();
  return true;
}

/// "Not this person": "Remove this image from this person?" — the pictures
/// only leave the person (nothing is deleted).
Future<bool> removeFromPerson(
  BuildContext context,
  WidgetRef ref,
  String? albumId,
  List<MediaItem> items,
) async {
  final personId = personIdOfAlbum(albumId);
  if (personId == null || items.isEmpty) return false;
  final ok = await showConfirmDialog(
    context,
    title: items.length == 1
        ? 'Remove this image from this person?'
        : 'Remove ${items.length} images from this person?',
    confirmLabel: 'Remove',
    destructive: false,
  );
  if (ok != true) return false;
  await ref.read(faceStoreProvider).removeFromPerson(personId, [
    for (final item in items) item.id,
  ]);
  ref.read(faceScanProvider.notifier).peopleChanged();
  return true;
}
