import 'package:flutter/material.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/classification/presentation/widgets/classification_section.dart';
import 'package:proalbums/shared/widgets/app_back_button.dart';

/// Albums > Intelligent classification > "More": every kind as a tile, 3
/// per row (People for now; Location, Documents and the things later).
class ClassificationPage extends StatelessWidget {
  const ClassificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(
          'Intelligent classification',
          style: context.textTheme.titleLarge,
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          const side = 16.0;
          const gap = 12.0;
          final tile = (constraints.maxWidth - side * 2 - gap * 2) / 3;
          return GridView(
            padding: const EdgeInsets.fromLTRB(side, 12, side, 24),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: gap,
              mainAxisSpacing: 16,
              mainAxisExtent: tile + 6 + 40,
            ),
            children: const [PeopleTile(), LocationTile()],
          );
        },
      ),
    );
  }
}
