import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:proalbums/app/router/app_routes.dart';
import 'package:proalbums/features/search/presentation/widgets/search_field.dart';
import 'package:proalbums/features/search/presentation/widgets/search_home.dart';
import 'package:proalbums/shared/widgets/collapsing_sliver_app_bar.dart';

/// The Search tab: big "Search" title, the search bar, Recent searches,
/// then People / Location / Types (Intelligent classification). The bar
/// and a recent search open the search page (SearchQueryPage) on top, in
/// this tab, so Back simply closes it.
class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  /// Opens the search page; [text] = search it at once (a recent search).
  static void openSearch(BuildContext context, [String text = '']) =>
      unawaited(context.push<void>(AppRoutes.searchQuery, extra: text));

  @override
  Widget build(BuildContext context) => Scaffold(
    body: CustomScrollView(
      slivers: [
        const CollapsingSliverAppBar(title: 'Search'),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SearchField(onTap: () => openSearch(context)),
          ),
        ),
        SearchHome(onRecent: (text) => openSearch(context, text)),
      ],
    ),
  );
}
