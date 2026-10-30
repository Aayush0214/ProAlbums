import 'package:proalbums/features/gallery/data/repositories/photo_manager_media_share_repository.dart';
import 'package:proalbums/features/gallery/domain/repositories/media_share_repository.dart';
import 'package:proalbums/features/gallery/domain/usecases/share_media.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'share_providers.g.dart';

@Riverpod(keepAlive: true)
MediaShareRepository mediaShareRepository(Ref ref) =>
    const PhotoManagerMediaShareRepository();

@Riverpod(keepAlive: true)
ShareMediaUseCase shareMediaUseCase(Ref ref) =>
    ShareMediaUseCase(ref.watch(mediaShareRepositoryProvider));
