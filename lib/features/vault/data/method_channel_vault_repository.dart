import 'package:flutter/services.dart';
import 'package:fpdart/fpdart.dart';
import 'package:proalbums/core/error/failures.dart';
import 'package:proalbums/core/logging/app_logger.dart';
import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/vault/domain/entities/vault_status.dart';
import 'package:proalbums/features/vault/domain/repositories/vault_repository.dart';

/// Talks to VaultChannel.kt (Android only).
final class MethodChannelVaultRepository implements VaultRepository {
  const MethodChannelVaultRepository();

  static const MethodChannel _channel = MethodChannel(
    'com.aayush.proalbums/vault',
  );

  /// One call; any platform error becomes a SecurityFailure with a short,
  /// safe message (the details are only logged, never shown).
  Future<Result<T>> _call<T>(
    String method,
    T Function(Object? value) read, {
    Map<String, Object?>? arguments,
    String failure = 'The private vault is not available right now.',
  }) async {
    try {
      final value = await _channel.invokeMethod<Object?>(method, arguments);
      return right(read(value));
    } on Object catch (error, stackTrace) {
      // Never log PINs, answers or keys: only the method and the error code.
      AppLogger.e(
        'Vault $method failed: '
        '${error is PlatformException ? error.code : error.runtimeType}',
        stackTrace: stackTrace,
      );
      return left(SecurityFailure(failure));
    }
  }

  static VaultCheck _check(Object? value) {
    final map = (value as Map<Object?, Object?>?) ?? const {};
    return VaultCheck(
      ok: map['ok'] == true,
      wait: Duration(milliseconds: (map['waitMillis'] as num?)?.toInt() ?? 0),
    );
  }

  @override
  FutureResult<VaultStatus> status() => _call('status', (value) {
    final map = (value as Map<Object?, Object?>?) ?? const {};
    return VaultStatus(
      created: map['created'] == true,
      passwordEnabled: map['passwordEnabled'] == true,
      hasPin: map['hasPin'] == true,
      recoveryKeySaved: map['recoveryKeySaved'] == true,
      unlocked: map['unlocked'] == true,
      wait: Duration(milliseconds: (map['waitMillis'] as num?)?.toInt() ?? 0),
    );
  });

  @override
  FutureResult<String> create() => _call(
    'create',
    (value) => value! as String,
    failure: 'Could not create the private vault.',
  );

  @override
  FutureResult<Unit> confirmRecoveryKeySaved() =>
      _call('confirmRecoveryKeySaved', (_) => unit);

  @override
  FutureResult<bool> unlockWithoutPassword() =>
      _call('unlockWithoutPassword', (value) => value == true);

  @override
  FutureResult<bool> unlockAfterBiometric() =>
      _call('unlockAfterBiometric', (value) => value == true);

  @override
  Future<void> lock() async {
    await _call('lock', (_) => unit);
  }

  @override
  FutureResult<Unit> setPinAndAnswers({
    required String pin,
    required List<String> answers,
  }) => _call(
    'setPinAndAnswers',
    (_) => unit,
    arguments: {'pin': pin, 'answers': answers},
    failure: 'Could not set the privacy password.',
  );

  @override
  FutureResult<VaultCheck> verifyPin(String pin) =>
      _call('verifyPin', _check, arguments: {'pin': pin});

  @override
  FutureResult<VaultCheck> verifyAnswers(List<String> answers) =>
      _call('verifyAnswers', _check, arguments: {'answers': answers});

  @override
  FutureResult<VaultCheck> setPinWithAnswers({
    required List<String> answers,
    required String pin,
  }) => _call(
    'setPinWithAnswers',
    _check,
    arguments: {'answers': answers, 'pin': pin},
  );

  @override
  FutureResult<VaultCheck> setPinWithRecoveryKey({
    required String recoveryKey,
    required String pin,
  }) => _call(
    'setPinWithRecoveryKey',
    _check,
    arguments: {'recoveryKey': recoveryKey, 'pin': pin},
  );

  @override
  FutureResult<Unit> setPasswordEnabled({required bool enabled}) =>
      _call('setPasswordEnabled', (_) => unit, arguments: {'enabled': enabled});

  @override
  Future<void> setSecure({required bool secure}) async {
    await _call('setSecure', (_) => unit, arguments: {'secure': secure});
  }

  @override
  FutureResult<bool> copyRecoveryKey(String recoveryKey) => _call(
    'copySensitive',
    (value) => value == true,
    arguments: {'text': recoveryKey},
    failure: 'Could not copy the Recovery Key.',
  );

  @override
  FutureResult<Unit> reset() => _call(
    'reset',
    (_) => unit,
    failure: 'Could not reset the private vault.',
  );

  @override
  FutureResult<HideResult> hide(
    List<({String id, bool video})> items, {
    void Function(int done, int total)? onProgress,
  }) async {
    // Progress comes back as calls from the native side.
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'hideProgress' && onProgress != null) {
        final map = call.arguments as Map<Object?, Object?>;
        onProgress(
          (map['done'] as num?)?.toInt() ?? 0,
          (map['total'] as num?)?.toInt() ?? items.length,
        );
      }
    });
    try {
      return await _call(
        'hide',
        (value) {
          final map = (value as Map<Object?, Object?>?) ?? const {};
          if (map['status'] == 'cancelled') return const HideResult.cancelled();
          return HideResult(
            hidden: (map['hidden'] as num?)?.toInt() ?? 0,
            failed: (map['failed'] as num?)?.toInt() ?? 0,
          );
        },
        arguments: {
          'items': [
            for (final item in items) {'id': item.id, 'video': item.video},
          ],
        },
        failure: 'Could not hide the selected items.',
      );
    } finally {
      _channel.setMethodCallHandler(null);
    }
  }

  @override
  FutureResult<int> count() =>
      _call('count', (value) => (value as num?)?.toInt() ?? 0);

  @override
  FutureResult<List<VaultEntry>> list() => _call('list', (value) {
    final rows = (value as List<Object?>?) ?? const [];
    return [
      for (final row in rows.cast<Map<Object?, Object?>>())
        VaultEntry(
          id: row['id']! as String,
          name: (row['name'] as String?) ?? '',
          video: row['video'] == true,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            (row['takenMs'] as num?)?.toInt() ?? 0,
          ),
          width: (row['width'] as num?)?.toInt() ?? 0,
          height: (row['height'] as num?)?.toInt() ?? 0,
          duration: Duration(
            milliseconds: (row['durationMs'] as num?)?.toInt() ?? 0,
          ),
          sizeBytes: (row['size'] as num?)?.toInt() ?? 0,
        ),
    ];
  });

  @override
  Future<Uint8List?> thumbnail(String id) async {
    try {
      return await _channel.invokeMethod<Uint8List>('thumbnail', {'id': id});
    } on Object catch (_) {
      return null;
    }
  }

  @override
  Future<Uint8List?> picture(String id, {required int maxLongEdge}) async {
    try {
      return await _channel.invokeMethod<Uint8List>('picture', {
        'id': id,
        'maxLongEdge': maxLongEdge,
      });
    } on Object catch (_) {
      return null;
    }
  }

  @override
  Future<({String name, int width, int height, int sizeBytes})?> details(
    String id,
  ) async {
    try {
      final map = await _channel.invokeMapMethod<String, Object?>('details', {
        'id': id,
      });
      if (map == null) return null;
      return (
        name: (map['name'] as String?) ?? '',
        width: (map['width'] as num?)?.toInt() ?? 0,
        height: (map['height'] as num?)?.toInt() ?? 0,
        sizeBytes: (map['size'] as num?)?.toInt() ?? 0,
      );
    } on Object catch (_) {
      return null;
    }
  }

  @override
  FutureResult<String> videoUrl(String id) => _call(
    'videoUrl',
    (value) => value! as String,
    arguments: {'id': id},
    failure: 'This video cannot be played.',
  );
}
