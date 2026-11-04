import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/vault/domain/entities/vault_status.dart';

/// The private vault's keys. The vault key itself never reaches Dart: it is
/// made, kept and wiped natively (VaultChannel.kt).
///
/// Answers are passed already normalized (see VaultRules.normalizeAnswer).
abstract interface class VaultRepository {
  FutureResult<VaultStatus> status();

  /// Makes the vault (first Hide). Returns the Recovery Key — show it once,
  /// never store it.
  FutureResult<String> create();

  /// The person confirmed they saved the Recovery Key.
  FutureResult<Unit> confirmRecoveryKeySaved();

  /// Opens the vault when "Password for hidden photos" is off.
  FutureResult<bool> unlockWithoutPassword();

  /// Opens the vault after the fingerprint was accepted.
  FutureResult<bool> unlockAfterBiometric();

  /// Wipes the vault key from memory.
  Future<void> lock();

  /// First PIN + answers; turns "Password for hidden photos" on.
  FutureResult<Unit> setPinAndAnswers({
    required String pin,
    required List<String> answers,
  });

  /// A right PIN also opens the vault.
  FutureResult<VaultCheck> verifyPin(String pin);

  FutureResult<VaultCheck> verifyAnswers(List<String> answers);

  /// Forgot PIN: the right answers set [pin] (and open the vault).
  FutureResult<VaultCheck> setPinWithAnswers({
    required List<String> answers,
    required String pin,
  });

  /// Forgot PIN and answers: the right Recovery Key sets [pin].
  FutureResult<VaultCheck> setPinWithRecoveryKey({
    required String recoveryKey,
    required String pin,
  });

  /// The settings switch (the vault must be open = verified first).
  FutureResult<Unit> setPasswordEnabled({required bool enabled});

  /// No screenshots / recording, blank in Recent apps (vault and security
  /// screens only).
  Future<void> setSecure({required bool secure});

  /// The Recovery Key on the clipboard, marked sensitive. true = Android
  /// shows its own "Copied" message.
  FutureResult<bool> copyRecoveryKey(String recoveryKey);

  /// Reset vault: every hidden item deleted for good, fresh start.
  FutureResult<Unit> reset();

  /// Hide (the vault must be unlocked): each item encrypted into the vault
  /// folder ([onProgress] after each), then ONE system request to delete
  /// the originals. [items] = MediaStore id + whether it is a video.
  FutureResult<HideResult> hide(
    List<({String id, bool video})> items, {
    void Function(int done, int total)? onProgress,
  });

  /// How many items are hidden.
  FutureResult<int> count();

  /// Every hidden item (the vault must be unlocked).
  FutureResult<List<VaultEntry>> list();

  /// The grid picture (JPEG), null when there is none.
  Future<Uint8List?> thumbnail(String id);

  /// The viewer picture, long side at most [maxLongEdge] (JPEG).
  Future<Uint8List?> picture(String id, {required int maxLongEdge});

  /// Name, size and resolution for the Info card (never the path).
  Future<({String name, int width, int height, int sizeBytes})?> details(
    String id,
  );
}

/// How the system fingerprint sheet ended.
enum BiometricResult {
  /// Recognised.
  success,

  /// The sheet's "Use password" button: show the PIN card.
  usePassword,

  /// Back / tap outside: close everything.
  cancelled,

  /// Locked out, sensor busy...: the PIN is the way.
  error,
}

/// The phone's fingerprint check (Android BiometricPrompt, strong
/// biometrics only — never the phone's own lock screen PIN).
abstract interface class VaultBiometrics {
  /// The phone can check a fingerprint (hardware + one enrolled).
  Future<bool> available();

  /// The system sheet alone, titled "Verify fingerprint", with a
  /// "Use password" button.
  Future<BiometricResult> authenticate();
}
