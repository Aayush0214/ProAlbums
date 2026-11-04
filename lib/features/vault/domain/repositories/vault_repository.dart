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
}
