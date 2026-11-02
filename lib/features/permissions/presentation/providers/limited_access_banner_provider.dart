import 'package:proalbums/features/permissions/domain/entities/media_permission_status.dart';
import 'package:proalbums/features/permissions/presentation/providers/media_permission_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'limited_access_banner_provider.g.dart';

/// The user closed the banner (for this app session).
@Riverpod(keepAlive: true)
class LimitedBannerDismissed extends _$LimitedBannerDismissed {
  @override
  bool build() => false;

  void dismiss() => state = true;
}

/// Show the "only some photos" banner? Only while the access really is
/// limited (iOS "Limited", Android 14 "Select photos"), and not after closing.
@riverpod
bool showLimitedAccessBanner(Ref ref) {
  final status = ref.watch(mediaPermissionProvider).value;
  final dismissed = ref.watch(limitedBannerDismissedProvider);
  return status == MediaPermissionStatus.limited && !dismissed;
}
