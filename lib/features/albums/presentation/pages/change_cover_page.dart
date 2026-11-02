import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/albums/presentation/providers/albums_providers.dart';
import 'package:proalbums/features/gallery/presentation/widgets/media_thumbnail.dart';

/// "Change cover": the pictures of ONE album; tapping one chooses it.
/// Returns the chosen picture's id (null = back).
class ChangeCoverPage extends ConsumerWidget {
  const ChangeCoverPage({required this.albumId, super.key});

  final String albumId;

  static const double _gap = 1;
  static const int _columns = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(albumItemsProvider(albumId)).value ?? const [];
    final width = MediaQuery.sizeOf(context).width;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cell = (width - _gap * (_columns - 1)) / _columns;
    final thumb = math.max(128, (cell * dpr / 64).ceil() * 64);

    return Scaffold(
      appBar: AppBar(
        title: Text('Choose cover', style: context.textTheme.titleLarge),
        centerTitle: true,
      ),
      body: GridView.builder(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _columns,
          mainAxisSpacing: _gap,
          crossAxisSpacing: _gap,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return GestureDetector(
            key: ValueKey(item.id),
            onTap: () => context.pop(item.id),
            child: MediaThumbnail(item: item, size: thumb),
          );
        },
      ),
    );
  }
}
