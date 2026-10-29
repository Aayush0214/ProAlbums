import 'package:flutter/widgets.dart';
import 'package:proalbums/core/usecase/usecase.dart';
import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/permissions/domain/entities/media_permission_status.dart';
import 'package:proalbums/features/permissions/presentation/providers/permission_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'media_permission_notifier.g.dart';

/// Single source of truth for "can we read the gallery?".
/// The router watches it (redirect) and the permission page drives it.
///
/// keepAlive: it must live as long as the app, the router depends on it.
@Riverpod(keepAlive: true)
class MediaPermission extends _$MediaPermission {
  @override
  Future<MediaPermissionStatus> build() {
    // The user may change the permission in system Settings and come back.
    // On every resume we silently re-check, so the UI always matches reality.
    final lifecycle = AppLifecycleListener(onResume: refresh);
    ref.onDispose(lifecycle.dispose);

    return _unwrap(
      ref.read(getMediaPermissionStatusUseCaseProvider)(const NoParams()),
    );
  }

  /// Re-reads the status (no dialog).
  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => _unwrap(
        ref.read(getMediaPermissionStatusUseCaseProvider)(const NoParams()),
      ),
    );
  }

  /// Shows the system dialog and stores the answer.
  Future<void> request() async {
    state = await AsyncValue.guard(
      () => _unwrap(
        ref.read(requestMediaPermissionUseCaseProvider)(const NoParams()),
      ),
    );
  }

  Future<void> openSettings() async {
    await ref.read(openAppSettingsUseCaseProvider)(const NoParams());
  }

  /// "Manage selected photos" (limited access), then re-check.
  Future<void> manageLimitedAccess() async {
    await ref.read(presentLimitedAccessUseCaseProvider)(const NoParams());
    await refresh();
  }

  // Either<Failure, T> -> value or AsyncError(failure). Riverpod's AsyncValue
  // is how the UI learns about loading / data / error.
  Future<MediaPermissionStatus> _unwrap(
    FutureResult<MediaPermissionStatus> future,
  ) async {
    final result = await future;
    return result.fold((failure) => throw failure, (status) => status);
  }
}
