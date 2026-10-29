import 'package:fpdart/fpdart.dart';
import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/permissions/domain/entities/media_permission_status.dart';

/// Contract only. The real work (photo_manager) lives in the data layer.
abstract interface class MediaPermissionRepository {
  /// Reads the current status WITHOUT showing any system dialog.
  FutureResult<MediaPermissionStatus> getStatus();

  /// Shows the system permission dialog (if the OS still allows it).
  FutureResult<MediaPermissionStatus> request();

  /// Opens this app's page in the system Settings.
  FutureResult<Unit> openAppSettings();

  /// Lets the user change which items the app may see (limited access).
  FutureResult<Unit> presentLimitedPicker();
}
