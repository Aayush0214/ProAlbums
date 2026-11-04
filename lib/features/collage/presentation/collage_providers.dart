import 'package:proalbums/features/collage/data/collage_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'collage_providers.g.dart';

@Riverpod(keepAlive: true)
CollageRepository collageRepository(Ref ref) =>
    const MethodChannelCollageRepository();
