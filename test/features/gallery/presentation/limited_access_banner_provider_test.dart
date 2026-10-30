import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/features/gallery/presentation/providers/limited_access_banner_provider.dart';
import 'package:proalbums/features/permissions/domain/entities/media_permission_status.dart';
import 'package:proalbums/features/permissions/presentation/providers/media_permission_notifier.dart';

class _FakePermission extends MediaPermission {
  _FakePermission(this._status);

  final MediaPermissionStatus _status;

  @override
  Future<MediaPermissionStatus> build() async => _status;
}

Future<ProviderContainer> _container(MediaPermissionStatus status) async {
  final container = ProviderContainer(
    overrides: [
      mediaPermissionProvider.overrideWith(() => _FakePermission(status)),
    ],
  );
  addTearDown(container.dispose);
  await container.read(mediaPermissionProvider.future);
  return container;
}

void main() {
  test('shown when the access is limited', () async {
    final c = await _container(MediaPermissionStatus.limited);
    expect(c.read(showLimitedAccessBannerProvider), isTrue);
  });

  test('not shown with full access', () async {
    final c = await _container(MediaPermissionStatus.granted);
    expect(c.read(showLimitedAccessBannerProvider), isFalse);
  });

  test('not shown after the user closed it', () async {
    final c = await _container(MediaPermissionStatus.limited);
    c.read(limitedBannerDismissedProvider.notifier).dismiss();
    expect(c.read(showLimitedAccessBannerProvider), isFalse);
  });
}
