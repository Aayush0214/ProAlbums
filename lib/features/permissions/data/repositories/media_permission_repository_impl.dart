import 'package:fpdart/fpdart.dart';
import 'package:proalbums/core/error/failures.dart';
import 'package:proalbums/core/utils/result_guard.dart';
import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/permissions/data/datasources/media_permission_data_source.dart';
import 'package:proalbums/features/permissions/data/mappers/permission_state_mapper.dart';
import 'package:proalbums/features/permissions/domain/entities/media_permission_status.dart';
import 'package:proalbums/features/permissions/domain/repositories/media_permission_repository.dart';

final class MediaPermissionRepositoryImpl implements MediaPermissionRepository {
  const MediaPermissionRepositoryImpl(this._dataSource);

  final MediaPermissionDataSource _dataSource;

  @override
  FutureResult<MediaPermissionStatus> getStatus() => guardAsync(
        () async => (await _dataSource.getState()).toDomain(),
        onError: (error, stackTrace) => PermissionFailure(
          'Could not check photo access.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );

  @override
  FutureResult<MediaPermissionStatus> request() => guardAsync(
        () async => (await _dataSource.request()).toDomain(),
        onError: (error, stackTrace) => PermissionFailure(
          'Could not request photo access.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );

  @override
  FutureResult<Unit> openAppSettings() => guardAsync(
        () async {
          await _dataSource.openSettings();
          return unit;
        },
        onError: (error, stackTrace) => PermissionFailure(
          'Could not open Settings.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );

  @override
  FutureResult<Unit> presentLimitedPicker() => guardAsync(
        () async {
          await _dataSource.presentLimited();
          return unit;
        },
        onError: (error, stackTrace) => PermissionFailure(
          'Could not open the photo picker.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
}
