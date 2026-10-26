import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

/// Represents the exact media access level granted by the OS
enum MediaPermissionStatus {
  granted,         // Full access to all photos & videos
  limited,         // Partial access (Android 14+ / iOS "Selected Photos")
  denied,          // Denied, can request again
  permanentlyDenied // Denied permanently, must open App Settings
}

class PermissionService {
  const PermissionService();

  /// Requests media permissions natively via PhotoManager (Android & iOS)
  Future<MediaPermissionStatus> requestMediaPermission() async {
    final PermissionState state = await PhotoManager.requestPermissionExtend(
      requestOption: const PermissionRequestOption(
        androidPermission: AndroidPermission(
          type: RequestType.common, // Both Images & Videos
          mediaLocation: true,      // For GPS Location clustering
        ),
      ),
    );

    return _mapPermissionState(state);
  }

  /// Opens the native OS picker when user has granted "Limited/Selected" access
  Future<void> presentLimitedMediaPicker() async {
    await PhotoManager.presentLimited(type: RequestType.common);
  }

  /// Opens OS App Settings if permission is permanently denied
  Future<void> openSettings() async {
    await PhotoManager.openSetting();
  }

  MediaPermissionStatus _mapPermissionState(PermissionState state) {
    switch (state) {
      case PermissionState.authorized:
        return MediaPermissionStatus.granted;
      case PermissionState.limited:
        return MediaPermissionStatus.limited;
      case PermissionState.denied:
        return MediaPermissionStatus.denied;
      case PermissionState.restricted:
      case PermissionState.notDetermined:
        return MediaPermissionStatus.permanentlyDenied;
    }
  }
}

final permissionServiceProvider = Provider<PermissionService>((ref) {
  return const PermissionService();
});