import 'package:flutter/material.dart';
import 'package:proalbums/shared/widgets/phase_placeholder.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) => const PhasePlaceholder(
        title: 'Search',
        message: 'Phase 7: search by name, date, album and type.',
      );
}
