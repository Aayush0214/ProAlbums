import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:proalbums/core/error/failures.dart';
import 'package:proalbums/features/permissions/data/datasources/media_permission_data_source.dart';
import 'package:proalbums/features/permissions/data/repositories/media_permission_repository_impl.dart';
import 'package:proalbums/features/permissions/domain/entities/media_permission_status.dart';

class MockPermissionDataSource extends Mock
    implements MediaPermissionDataSource {}

void main() {
  late MockPermissionDataSource dataSource;
  late MediaPermissionRepositoryImpl repository;

  setUp(() {
    dataSource = MockPermissionDataSource();
    repository = MediaPermissionRepositoryImpl(dataSource);
  });

  group('getStatus', () {
    const expectedMapping = {
      PermissionState.authorized: MediaPermissionStatus.granted,
      PermissionState.limited: MediaPermissionStatus.limited,
      PermissionState.denied: MediaPermissionStatus.denied,
      PermissionState.restricted: MediaPermissionStatus.restricted,
      PermissionState.notDetermined: MediaPermissionStatus.notDetermined,
    };

    for (final entry in expectedMapping.entries) {
      test('maps ${entry.key} to ${entry.value}', () async {
        when(() => dataSource.getState()).thenAnswer((_) async => entry.key);

        final result = await repository.getStatus();

        expect(result, right<Failure, MediaPermissionStatus>(entry.value));
      });
    }

    test('returns a PermissionFailure when the plugin throws', () async {
      when(() => dataSource.getState()).thenThrow(Exception('boom'));

      final result = await repository.getStatus();

      result.match(
        (failure) => expect(failure, isA<PermissionFailure>()),
        (_) => fail('Expected a failure'),
      );
    });
  });

  group('request', () {
    test('returns the status chosen by the user', () async {
      when(() => dataSource.request())
          .thenAnswer((_) async => PermissionState.limited);

      final result = await repository.request();

      expect(
        result,
        right<Failure, MediaPermissionStatus>(MediaPermissionStatus.limited),
      );
    });
  });

  group('MediaPermissionStatus.hasAccess', () {
    test('granted and limited can show the gallery, others cannot', () {
      expect(MediaPermissionStatus.granted.hasAccess, isTrue);
      expect(MediaPermissionStatus.limited.hasAccess, isTrue);
      expect(MediaPermissionStatus.denied.hasAccess, isFalse);
      expect(MediaPermissionStatus.notDetermined.hasAccess, isFalse);
      expect(MediaPermissionStatus.restricted.hasAccess, isFalse);
    });
  });
}
