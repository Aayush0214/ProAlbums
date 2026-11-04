import 'package:flutter/services.dart';
import 'package:proalbums/core/logging/app_logger.dart';
import 'package:proalbums/features/vault/domain/repositories/vault_repository.dart';

/// The system fingerprint sheet through VaultChannel.kt (Android
/// BiometricPrompt directly, not local_auth: local_auth reports the sheet's
/// "Use password" button and a plain cancel the same way, so the app could
/// not tell "show the PIN" from "close").
final class NativeVaultBiometrics implements VaultBiometrics {
  const NativeVaultBiometrics();

  static const MethodChannel _channel = MethodChannel(
    'com.aayush.proalbums/vault',
  );

  @override
  Future<bool> available() async {
    try {
      return await _channel.invokeMethod<bool>('biometricAvailable') ?? false;
    } on Object catch (error) {
      AppLogger.e('Biometrics unavailable: ${error.runtimeType}');
      return false;
    }
  }

  @override
  Future<BiometricResult> authenticate() async {
    try {
      final answer = await _channel.invokeMethod<String>(
        'authenticateBiometric',
        {'title': 'Verify fingerprint', 'usePassword': 'Use password'},
      );
      return switch (answer) {
        'ok' => BiometricResult.success,
        'usePassword' => BiometricResult.usePassword,
        'cancelled' => BiometricResult.cancelled,
        _ => BiometricResult.error,
      };
    } on Object catch (error) {
      AppLogger.e('Biometric check failed: ${error.runtimeType}');
      return BiometricResult.error;
    }
  }
}
