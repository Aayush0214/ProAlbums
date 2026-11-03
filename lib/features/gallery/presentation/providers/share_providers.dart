import 'package:proalbums/features/gallery/data/repositories/method_channel_media_clipboard_repository.dart';
import 'package:proalbums/features/gallery/data/repositories/photo_manager_media_share_repository.dart';
import 'package:proalbums/features/gallery/domain/repositories/media_clipboard_repository.dart';
import 'package:proalbums/features/gallery/domain/repositories/media_share_repository.dart';
import 'package:proalbums/features/gallery/domain/usecases/copy_to_clipboard.dart';
import 'package:proalbums/features/gallery/domain/usecases/share_media.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'share_providers.g.dart';

@Riverpod(keepAlive: true)
MediaShareRepository mediaShareRepository(Ref ref) =>
    const PhotoManagerMediaShareRepository();

@Riverpod(keepAlive: true)
ShareMediaUseCase shareMediaUseCase(Ref ref) =>
    ShareMediaUseCase(ref.watch(mediaShareRepositoryProvider));

@Riverpod(keepAlive: true)
MediaClipboardRepository mediaClipboardRepository(Ref ref) =>
    const MethodChannelMediaClipboardRepository();

@Riverpod(keepAlive: true)
CopyToClipboardUseCase copyToClipboardUseCase(Ref ref) =>
    CopyToClipboardUseCase(ref.watch(mediaClipboardRepositoryProvider));
