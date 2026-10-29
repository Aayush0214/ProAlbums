import 'package:photo_manager/photo_manager.dart';

/// Thin wrapper around the plugin. Having an interface lets tests replace the
/// plugin with a fake (no phone needed).
abstract interface class MediaPermissionDataSource {
  Future<PermissionState> getState();
  Future<PermissionState> request();
  Future<void> openSettings();
  Future<void> presentLimited();
}

final class PhotoManagerPermissionDataSource
    implements MediaPermissionDataSource {
  const PhotoManagerPermissionDataSource();

  // Ask only for photos + videos. `mediaLocation: false` skips the extra
  // "photo location" permission, we will ask for it in Phase 8 (Location
  // categories) at the moment the user actually needs it.
  static const PermissionRequestOption _option = PermissionRequestOption(
    androidPermission: AndroidPermission(
      type: RequestType.common,
      mediaLocation: false,
    ),
  );

  @override
  Future<PermissionState> getState() =>
      PhotoManager.getPermissionState(requestOption: _option);

  @override
  Future<PermissionState> request() =>
      PhotoManager.requestPermissionExtend(requestOption: _option);

  @override
  Future<void> openSettings() => PhotoManager.openSetting();

  @override
  Future<void> presentLimited() => PhotoManager.presentLimited();
}
