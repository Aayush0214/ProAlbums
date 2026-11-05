import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/albums/presentation/widgets/album_selection_widgets.dart';
import 'package:proalbums/features/classification/presentation/people_flows.dart';
import 'package:proalbums/features/classification/presentation/people_providers.dart';
import 'package:proalbums/features/classification/presentation/widgets/people_grid.dart';

/// People > "+": the other people found (also the hidden ones), to put on
/// the People page: tap to choose, then Add.
class AddPeoplePage extends ConsumerStatefulWidget {
  const AddPeoplePage({super.key});

  @override
  ConsumerState<AddPeoplePage> createState() => _AddPeoplePageState();
}

class _AddPeoplePageState extends ConsumerState<AddPeoplePage> {
  Set<int> _selected = const {};

  Future<void> _add() async {
    await showPeople(ref, _selected, shown: true);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final people = ref.watch(peopleToAddProvider);
    final chosen = [
      for (final p in people)
        if (_selected.contains(p.id)) p,
    ];

    return Scaffold(
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(48, 8, 48, 12),
          child: SizedBox(
            height: 52,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                shape: const StadiumBorder(),
                side: BorderSide(
                  color: chosen.isEmpty
                      ? Theme.of(context).disabledColor
                      : context.colorScheme.primary,
                  width: 2,
                ),
              ),
              onPressed: chosen.isEmpty ? null : _add,
              child: const Text('Add'),
            ),
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          AlbumSelectionHeader(
            selectedCount: chosen.length,
            itemCount: people.length,
            subtitle: chosen.isEmpty ? null : picturesInTotal(chosen),
            onSelectAllToggle: () => setState(
              () => _selected = chosen.length == people.length
                  ? const {}
                  : {for (final p in people) p.id},
            ),
            onClose: () => context.pop(),
          ),
          if (people.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'Everyone found is already on the People page',
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
            )
          else
            PeopleGridSliver(
              people: people,
              selected: _selected,
              onTap: (person) => setState(() {
                final next = {..._selected};
                if (!next.remove(person.id)) next.add(person.id);
                _selected = next;
              }),
            ),
        ],
      ),
    );
  }
}
