import 'package:flutter/material.dart';
import 'package:proalbums/shared/widgets/phase_placeholder.dart';

class ForYouPage extends StatelessWidget {
  const ForYouPage({super.key});

  @override
  Widget build(BuildContext context) => const PhasePlaceholder(
        title: 'For You',
        message: 'Phase 10: memories and featured photos.',
      );
}
