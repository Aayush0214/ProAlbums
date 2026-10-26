import 'package:flutter/material.dart';
import 'package:proalbums/shared/widgets/phase_placeholder.dart';

class AlbumsPage extends StatelessWidget {
  const AlbumsPage({super.key});

  @override
  Widget build(BuildContext context) => const PhasePlaceholder(
        title: 'Albums',
        message: 'Phase 5: albums, cleanup and recently deleted rows.',
      );
}
