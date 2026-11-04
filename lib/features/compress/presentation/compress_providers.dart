import 'package:proalbums/core/database/database_providers.dart';
import 'package:proalbums/features/compress/data/drift_compressed_media_repository.dart';
import 'package:proalbums/features/compress/data/method_channel_compress_repository.dart';
import 'package:proalbums/features/compress/domain/compress_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'compress_providers.g.dart';

@Riverpod(keepAlive: true)
CompressRepository compressRepository(Ref ref) =>
    const MethodChannelCompressRepository();

@Riverpod(keepAlive: true)
CompressedMediaRepository compressedMediaRepository(Ref ref) =>
    DriftCompressedMediaRepository(ref.watch(appDatabaseProvider));

/// Every compressed copy: id → bytes. The grid ROW asks it once for all its
/// tiles (a bit per tile, like the hearts), so this costs nothing per tile.
@Riverpod(keepAlive: true)
Stream<Map<String, int>> compressedSizes(Ref ref) =>
    ref.watch(compressedMediaRepositoryProvider).watch();
