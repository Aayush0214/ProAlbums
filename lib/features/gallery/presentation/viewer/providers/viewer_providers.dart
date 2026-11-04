import 'package:proalbums/features/gallery/data/repositories/method_channel_media_edit_repository.dart';
import 'package:proalbums/features/gallery/data/repositories/method_channel_video_frame_repository.dart';
import 'package:proalbums/features/gallery/data/repositories/method_channel_video_tools_repository.dart';
import 'package:proalbums/features/gallery/data/repositories/photo_manager_media_image_repository.dart';
import 'package:proalbums/features/gallery/data/repositories/photo_manager_video_source_repository.dart';
import 'package:proalbums/features/gallery/domain/repositories/media_edit_repository.dart';
import 'package:proalbums/features/gallery/domain/repositories/media_image_repository.dart';
import 'package:proalbums/features/gallery/domain/repositories/video_frame_repository.dart';
import 'package:proalbums/features/gallery/domain/repositories/video_source_repository.dart';
import 'package:proalbums/features/gallery/domain/repositories/video_tools_repository.dart';
import 'package:proalbums/features/gallery/domain/usecases/get_video_frame.dart';
import 'package:proalbums/features/gallery/domain/usecases/load_display_image.dart';
import 'package:proalbums/features/gallery/domain/usecases/resolve_video_source.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'viewer_providers.g.dart';

@Riverpod(keepAlive: true)
MediaImageRepository mediaImageRepository(Ref ref) =>
    const PhotoManagerMediaImageRepository();

@Riverpod(keepAlive: true)
LoadDisplayImageUseCase loadDisplayImageUseCase(Ref ref) =>
    LoadDisplayImageUseCase(ref.watch(mediaImageRepositoryProvider));

@Riverpod(keepAlive: true)
VideoSourceRepository videoSourceRepository(Ref ref) =>
    const PhotoManagerVideoSourceRepository();

@Riverpod(keepAlive: true)
ResolveVideoSourceUseCase resolveVideoSourceUseCase(Ref ref) =>
    ResolveVideoSourceUseCase(ref.watch(videoSourceRepositoryProvider));

@Riverpod(keepAlive: true)
VideoFrameRepository videoFrameRepository(Ref ref) =>
    MethodChannelVideoFrameRepository();

@Riverpod(keepAlive: true)
GetVideoFrameUseCase getVideoFrameUseCase(Ref ref) =>
    GetVideoFrameUseCase(ref.watch(videoFrameRepositoryProvider));

@Riverpod(keepAlive: true)
VideoToolsRepository videoToolsRepository(Ref ref) =>
    const MethodChannelVideoToolsRepository();

@Riverpod(keepAlive: true)
MediaEditRepository mediaEditRepository(Ref ref) =>
    const MethodChannelMediaEditRepository();
