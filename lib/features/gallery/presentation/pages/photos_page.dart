import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proalbums/core/error/failures.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/gallery/presentation/providers/phase1_check_providers.dart';
import 'package:proalbums/features/gallery/presentation/widgets/media_thumbnail.dart';

/// TEMPORARY verification screen (Phase 2 replaces it with the real grid).
class PhotosPage extends ConsumerWidget {
  const PhotosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(mediaCountProvider);
    final firstPage = ref.watch(firstMediaPageProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Photos')),
      body: firstPage.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text(error is Failure ? error.message : 'Something went wrong'),
        ),
        data: (page) => CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Text(
                  '${count.value ?? '...'} items on this device '
                      '(showing first ${page.items.length})',
                  style: context.textTheme.bodySmall,
                ),
              ),
            ),
            SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
              ),
              itemCount: page.items.length,
              itemBuilder: (context, index) =>
                  MediaThumbnail(item: page.items[index]),
            ),
            // Keeps the last row above the glass bottom bar.
            SliverToBoxAdapter(
              child: SizedBox(height: MediaQuery.paddingOf(context).bottom),
            ),
          ],
        ),
      ),
    );
  }
}
