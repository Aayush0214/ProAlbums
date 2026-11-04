import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proalbums/features/compress/domain/compress_repository.dart';
import 'package:proalbums/features/compress/domain/compress_rules.dart';
import 'package:proalbums/features/compress/presentation/compress_progress_card.dart';
import 'package:proalbums/features/compress/presentation/compress_providers.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/viewer/providers/video_playback_controller.dart';
import 'package:proalbums/features/gallery/presentation/viewer/providers/viewer_session_provider.dart';
import 'package:proalbums/shared/widgets/app_snack_bar.dart';

/// Viewer > More > Convert to standard codec (H.264), like the system
/// gallery: a "Transcoding" card over the viewer (bar, %, Cancel), then a NEW
/// copy in H.264 at the same size next to the original (which stays), toast
/// "Transcoded video saved", and the viewer shows the copy. A video that is
/// already H.264 is left alone.
Future<void> convertVideoToH264(
  BuildContext context,
  WidgetRef ref,
  MediaItem item,
) async {
  final repository = ref.read(compressRepositoryProvider);
  final toast = AppToast.of(context);

  final codec = await repository.videoCodec(item.id);
  if (!context.mounted) return;
  if (isH264(codec)) {
    toast.show('This video is already H.264');
    return;
  }
  final info = await repository.videoInfo(item.id);
  if (!context.mounted) return;
  if (info == null || info.durationMs <= 0) {
    toast.show('This video cannot be converted');
    return;
  }

  unawaited(ref.read(videoPlaybackProvider.notifier).pause());
  final progress = ValueNotifier<int>(0);
  final navigator = Navigator.of(context);
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        // Back = Cancel (the card closes when the phone stopped).
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) unawaited(repository.cancelVideo());
        },
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: ValueListenableBuilder<int>(
              valueListenable: progress,
              builder: (context, percent, _) => CompressProgressCard(
                title: 'Transcoding',
                percent: percent,
                onCancel: repository.cancelVideo,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  final result = await repository.convertToH264(
    item.id,
    bitrate: h264BitrateFor(info),
    onProgress: (percent) => progress.value = percent.clamp(0, 100),
  );
  navigator.pop();
  progress.dispose();

  switch (result) {
    case VideoCompressed(:final copy):
      toast.show('Transcoded video saved');
      ref.read(viewerJumpProvider.notifier).to(copy.id);
    case VideoCompressCancelled():
      break;
    case VideoCompressFailed():
      toast.show('Could not convert this video');
  }
}
