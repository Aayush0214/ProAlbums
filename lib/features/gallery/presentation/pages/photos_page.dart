import 'package:flutter/material.dart';
import 'package:proalbums/shared/widgets/phase_placeholder.dart';

class PhotosPage extends StatelessWidget {
  const PhotosPage({super.key});

  @override
  Widget build(BuildContext context) => const PhasePlaceholder(
        title: 'Photos',
        message: 'Phase 2: date-wise photo grid will be built here.',
      );
}
