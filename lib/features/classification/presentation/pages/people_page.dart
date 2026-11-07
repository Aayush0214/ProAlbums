import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/app/router/app_routes.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/albums/presentation/widgets/album_selection_widgets.dart';
import 'package:proalbums/features/classification/data/face_repository.dart';
import 'package:proalbums/features/classification/presentation/classification_providers.dart';
import 'package:proalbums/features/classification/presentation/people_flows.dart';
import 'package:proalbums/features/classification/presentation/people_providers.dart';
import 'package:proalbums/features/classification/presentation/widgets/people_grid.dart';
import 'package:proalbums/shared/widgets/app_back_button.dart';
import 'package:proalbums/shared/widgets/collapsing_sliver_app_bar.dart';

/// Intelligent classification > People (like the system gallery): the
/// people as circles, 3 per row (no zoom); named ones first with their name.
/// Select (icon or long press) → Hide (off this page only, "+" brings them
/// back) / Merge (2 or more). "+" = the other people found.
class PeoplePage extends ConsumerStatefulWidget {
  const PeoplePage({this.onOpenPerson, super.key});

  /// Opens a person instead of the person page (the Search tab opens a
  /// plain grid, no slideshow). null = the person page.
  final void Function(BuildContext context, PersonSummary person)? onOpenPerson;

  @override
  ConsumerState<PeoplePage> createState() => _PeoplePageState();
}

class _PeoplePageState extends ConsumerState<PeoplePage> {
  /// null = not selecting.
  Set<int>? _selected;

  void _toggle(PersonSummary person) => setState(() {
    final next = {...?_selected};
    if (!next.remove(person.id)) next.add(person.id);
    _selected = next;
  });

  void _exit() => setState(() => _selected = null);

  Future<void> _hide(List<PersonSummary> chosen) async {
    await showPeople(ref, [for (final p in chosen) p.id], shown: false);
    if (mounted) _exit();
  }

  Future<void> _merge(List<PersonSummary> chosen) async {
    final done = await mergePeople(context, ref, chosen);
    if (done && mounted) _exit();
  }

  @override
  Widget build(BuildContext context) {
    final people = ref.watch(peopleShownProvider);
    final ready = ref.watch(faceScanProvider.select((s) => s.ready));
    final loading = ref.watch(allPeopleProvider).isLoading && people.isEmpty;
    final selected = _selected;
    final chosen = selected == null
        ? const <PersonSummary>[]
        : [
            for (final p in people)
              if (selected.contains(p.id)) p,
          ];

    final Widget header = selected != null
        ? AlbumSelectionHeader(
            selectedCount: chosen.length,
            itemCount: people.length,
            subtitle: chosen.isEmpty ? null : picturesInTotal(chosen),
            onSelectAllToggle: () => setState(
              () => _selected = chosen.length == people.length
                  ? <int>{}
                  : {for (final p in people) p.id},
            ),
            onClose: _exit,
          )
        : CollapsingSliverAppBar(
            title: 'People',
            leading: const AppBackButton(),
            actions: [
              if (people.isNotEmpty)
                IconButton(
                  tooltip: 'Select',
                  icon: const Icon(LucideIcons.squareCheck),
                  onPressed: () => setState(() => _selected = <int>{}),
                ),
              IconButton(
                tooltip: 'Add people',
                icon: const Icon(LucideIcons.userPlus),
                onPressed: () =>
                    unawaited(context.push<void>(AppRoutes.addPeople)),
              ),
            ],
          );

    return PopScope(
      canPop: selected == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _exit();
      },
      child: Scaffold(
        bottomNavigationBar: selected == null
            ? null
            : PeopleActionBar(
                actions: [
                  (
                    icon: LucideIcons.eyeOff,
                    label: 'Hide',
                    onPressed: chosen.isEmpty ? null : () => _hide(chosen),
                    destructive: false,
                  ),
                  (
                    icon: LucideIcons.merge,
                    label: 'Merge',
                    onPressed: chosen.length < 2 ? null : () => _merge(chosen),
                    destructive: false,
                  ),
                ],
              ),
        body: CustomScrollView(
          slivers: [
            header,
            if (people.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    loading || !ready ? 'Scanning…' : 'No people yet',
                    style: context.textTheme.bodyLarge?.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
              )
            else
              PeopleGridSliver(
                people: people,
                selected: selected,
                onTap: (person) => selected != null
                    ? _toggle(person)
                    : widget.onOpenPerson != null
                    ? widget.onOpenPerson!(context, person)
                    : unawaited(
                        context.push<void>(AppRoutes.person(person.id)),
                      ),
                onLongPress: selected != null
                    ? null
                    : (person) => setState(() => _selected = {person.id}),
              ),
          ],
        ),
      ),
    );
  }
}
