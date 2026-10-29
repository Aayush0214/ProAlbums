import 'package:proalbums/features/permissions/data/datasources/media_permission_data_source.dart';
import 'package:proalbums/features/permissions/data/repositories/media_permission_repository_impl.dart';
import 'package:proalbums/features/permissions/domain/repositories/media_permission_repository.dart';
import 'package:proalbums/features/permissions/domain/usecases/get_media_permission_status.dart';
import 'package:proalbums/features/permissions/domain/usecases/open_app_settings.dart';
import 'package:proalbums/features/permissions/domain/usecases/present_limited_access.dart';
import 'package:proalbums/features/permissions/domain/usecases/request_media_permission.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'permission_providers.g.dart';

// Dependency wiring for the permissions feature (this is our "DI").
// Rule: only THIS file knows which concrete class implements which interface.
// Tests override these providers with fakes.

@Riverpod(keepAlive: true)
MediaPermissionDataSource mediaPermissionDataSource(Ref ref) =>
    const PhotoManagerPermissionDataSource();

@Riverpod(keepAlive: true)
MediaPermissionRepository mediaPermissionRepository(Ref ref) =>
    MediaPermissionRepositoryImpl(ref.watch(mediaPermissionDataSourceProvider));

@Riverpod(keepAlive: true)
GetMediaPermissionStatus getMediaPermissionStatusUseCase(Ref ref) =>
    GetMediaPermissionStatus(ref.watch(mediaPermissionRepositoryProvider));

@Riverpod(keepAlive: true)
RequestMediaPermission requestMediaPermissionUseCase(Ref ref) =>
    RequestMediaPermission(ref.watch(mediaPermissionRepositoryProvider));

@Riverpod(keepAlive: true)
OpenAppSettings openAppSettingsUseCase(Ref ref) =>
    OpenAppSettings(ref.watch(mediaPermissionRepositoryProvider));

@Riverpod(keepAlive: true)
PresentLimitedAccess presentLimitedAccessUseCase(Ref ref) =>
    PresentLimitedAccess(ref.watch(mediaPermissionRepositoryProvider));
