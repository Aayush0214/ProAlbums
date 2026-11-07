import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proalbums/core/logging/app_logger.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/memories/data/memory_platform.dart';
import 'package:proalbums/features/memories/data/memory_repository.dart';
import 'package:proalbums/features/memories/domain/memory_music.dart';
import 'package:proalbums/features/memories/domain/memory_rules.dart';
import 'package:proalbums/features/memories/presentation/memory_providers.dart';
import 'package:proalbums/shared/widgets/app_snack_bar.dart';
import 'package:share_plus/share_plus.dart';

/// ⋮ > Export video file: the memory (its shown pictures, its music) as an
/// MP4 in Movies/ProAlbums. The new video's id, or null.
Future<String?> exportMemoryVideo(
  BuildContext context,
  WidgetRef ref,
  StoredMemory memory,
) async {
  final toast = AppToast.of(context);
  final outcome = await _make(context, ref, memory, toGallery: true);
  if (outcome == null) {
    toast.show('The video could not be made');
    return null;
  }
  if (outcome.cancelled) return null;
  toast.show('Video saved to Movies/ProAlbums');
  return outcome.id;
}

/// Share: the memory as a video (made in the cache, not kept in the
/// gallery), then Android's share sheet.
Future<void> shareMemoryVideo(
  BuildContext context,
  WidgetRef ref,
  StoredMemory memory,
) async {
  final toast = AppToast.of(context);
  final outcome = await _make(context, ref, memory, toGallery: false);
  if (outcome == null || outcome.path == null) {
    if (outcome?.cancelled != true) toast.show('The video could not be made');
    return;
  }
  try {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(outcome.path!, mimeType: 'video/mp4')],
        subject: memory.title,
      ),
    );
  } on Object catch (error, stackTrace) {
    AppLogger.e('Share memory failed', error: error, stackTrace: stackTrace);
    toast.show('Could not share the video');
  }
}

/// Makes the video with a progress card (Cancel; Back = Cancel).
Future<ExportOutcome?> _make(
  BuildContext context,
  WidgetRef ref,
  StoredMemory memory, {
  required bool toGallery,
}) async {
  final platform = ref.read(memoryPlatformProvider);
  final progress = ValueNotifier<int>(0);
  final navigator = Navigator.of(context);
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ExportDialog(
        title: toGallery ? 'Exporting video' : 'Preparing video',
        progress: progress,
        onCancel: () => unawaited(platform.cancelExport()),
      ),
    ),
  );
  final outcome = await platform.exportVideo(
    ids: memory.shown,
    audio: musicSource(memory.music),
    audioStartMs: memory.music.startMs,
    perPictureMs: memoryPerPicture.inMilliseconds,
    toGallery: toGallery,
    onProgress: (percent) => progress.value = percent,
  );
  if (navigator.mounted) navigator.pop();
  progress.dispose();
  return outcome;
}

class _ExportDialog extends StatelessWidget {
  const _ExportDialog({
    required this.title,
    required this.progress,
    required this.onCancel,
  });

  final String title;
  final ValueNotifier<int> progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) onCancel();
    },
    child: Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        child: ValueListenableBuilder<int>(
          valueListenable: progress,
          builder: (context, percent, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.textTheme.titleLarge),
              const SizedBox(height: 20),
              LinearProgressIndicator(value: percent / 100),
              const SizedBox(height: 8),
              Text(
                '$percent%',
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onCancel,
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
