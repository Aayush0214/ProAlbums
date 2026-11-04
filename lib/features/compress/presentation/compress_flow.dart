import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:proalbums/app/router/app_routes.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/compress/domain/compress_rules.dart';
import 'package:proalbums/features/compress/presentation/compress_providers.dart';
import 'package:proalbums/features/compress/presentation/compress_video_page.dart';
import 'package:proalbums/features/compress/presentation/image_compress_sheet.dart';
import 'package:proalbums/features/compress/presentation/video_compress_dialog.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/viewer/providers/viewer_session_provider.dart';
import 'package:proalbums/shared/widgets/app_snack_bar.dart';

/// Viewer > More > Compress size. Always a NEW smaller copy next to the
/// original (same folder, same date); the viewer then shows the copy.
///  - picture: the sheet (resolution, quality, live size) → a short
///    "Compressing" wait → toast → the copy;
///  - video: the resolution list → its own page with progress (see
///    CompressVideoPage).
Future<void> compressMediaItem(
  BuildContext context,
  WidgetRef ref,
  MediaItem item,
) async {
  final repository = ref.read(compressRepositoryProvider);
  final toast = AppToast.of(context);

  if (item.isVideo) {
    final info = await repository.videoInfo(item.id);
    if (!context.mounted) return;
    final options = info == null
        ? const <VideoCompressOption>[]
        : videoOptionsFor(info);
    if (info == null || options.isEmpty) {
      toast.show('This video cannot be compressed');
      return;
    }
    final option = await showVideoCompressDialog(
      context,
      info: info,
      options: options,
    );
    if (option == null || !context.mounted) return;
    final CompressVideoRequest request = (item: item, option: option);
    await context.push<void>(AppRoutes.compressVideo, extra: request);
    return;
  }

  final info = await repository.imageInfo(item.id);
  if (!context.mounted) return;
  if (info == null) {
    toast.show('This picture cannot be compressed');
    return;
  }
  final choice = await showImageCompressSheet(
    context,
    id: item.id,
    info: info,
    repository: repository,
  );
  if (choice == null || !context.mounted) return;

  final navigator = Navigator.of(context);
  final copyFuture = repository.compressImage(
    item.id,
    scale: choice.scale,
    quality: choice.quality,
  );
  // A short wait (big pictures take a second or two); cannot be closed.
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _CompressingDialog(),
    ),
  );
  final copy = await copyFuture;
  navigator.pop();
  if (copy == null) {
    toast.show('Could not compress this picture');
    return;
  }
  toast.show('Compressed image saved');
  ref.read(viewerJumpProvider.notifier).to(copy.id);
}

class _CompressingDialog extends StatelessWidget {
  const _CompressingDialog();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Compressing',
                textAlign: TextAlign.center,
                style: context.textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(minHeight: 4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
