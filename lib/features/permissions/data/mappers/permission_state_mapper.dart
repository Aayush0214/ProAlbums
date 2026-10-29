import 'package:photo_manager/photo_manager.dart';
import 'package:proalbums/features/permissions/domain/entities/media_permission_status.dart';

/// Plugin type -> our own domain type. The rest of the app never sees
/// `PermissionState`, so replacing photo_manager later touches only data/.
extension PermissionStateMapper on PermissionState {
  MediaPermissionStatus toDomain() => switch (this) {
        PermissionState.authorized => MediaPermissionStatus.granted,
        PermissionState.limited => MediaPermissionStatus.limited,
        PermissionState.denied => MediaPermissionStatus.denied,
        PermissionState.restricted => MediaPermissionStatus.restricted,
        PermissionState.notDetermined => MediaPermissionStatus.notDetermined,
      };
}
