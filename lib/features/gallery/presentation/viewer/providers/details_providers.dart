import 'dart:ui' as ui;

import 'package:proalbums/features/gallery/data/repositories/photo_manager_media_details_repository.dart';
import 'package:proalbums/features/gallery/domain/entities/media_details.dart';
import 'package:proalbums/features/gallery/domain/entities/thumbnail_request.dart';
import 'package:proalbums/features/gallery/domain/repositories/media_details_repository.dart';
import 'package:proalbums/features/gallery/domain/usecases/get_media_details.dart';
import 'package:proalbums/features/gallery/presentation/providers/media_providers.dart';
import 'package:proalbums/features/gallery/presentation/viewer/histogram.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'details_providers.g.dart';

@Riverpod(keepAlive: true)
MediaDetailsRepository mediaDetailsRepository(Ref ref) =>
    const PhotoManagerMediaDetailsRepository();

@Riverpod(keepAlive: true)
GetMediaDetailsUseCase getMediaDetailsUseCase(Ref ref) =>
    GetMediaDetailsUseCase(ref.watch(mediaDetailsRepositoryProvider));

/// Details of one item. Loaded when the Info card opens, dropped when it closes.
@riverpod
Future<MediaDetails?> mediaDetails(Ref ref, String id) async {
  final result = await ref.watch(getMediaDetailsUseCaseProvider)(id);
  return result.fold((failure) => null, (details) => details);
}

/// The brightness graph of one picture, made from its small thumbnail (a
/// 96-pixel picture has about 9,000 pixels: instant).
@riverpod
Future<HistogramData?> mediaHistogram(Ref ref, String id) async {
  final result = await ref.watch(getMediaThumbnailUseCaseProvider)(
    ThumbnailRequest(id: id, size: 128),
  );
  final bytes = result.fold((failure) => null, (bytes) => bytes);
  if (bytes == null) return null;

  final codec = await ui.instantiateImageCodec(bytes, targetWidth: 96);
  try {
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
    frame.image.dispose();
    if (data == null) return null;
    return HistogramData.fromRgba(data.buffer.asUint8List());
  } finally {
    codec.dispose();
  }
}
