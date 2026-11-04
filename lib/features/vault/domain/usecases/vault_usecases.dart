import 'package:fpdart/fpdart.dart';
import 'package:proalbums/core/error/failures.dart';
import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/vault/domain/entities/vault_status.dart';
import 'package:proalbums/features/vault/domain/repositories/vault_repository.dart';
import 'package:proalbums/features/vault/domain/vault_rules.dart';

/// A new PIN typed twice: the same, 6 digits. null = fine, else the reason.
String? newPinProblem(String pin, String confirm) {
  if (!VaultRules.isValidPin(pin)) {
    return 'Enter ${VaultRules.pinLength} digits.';
  }
  if (pin != confirm) return 'The passwords do not match.';
  return null;
}

/// Turning "Password for hidden photos" on the first time: PIN (twice) and
/// both security answers.
final class SetUpVaultPasswordUseCase {
  const SetUpVaultPasswordUseCase(this._repository);

  final VaultRepository _repository;

  FutureResult<Unit> call({
    required String pin,
    required String confirm,
    required List<String> answers,
  }) async {
    final problem = newPinProblem(pin, confirm);
    if (problem != null) return left(SecurityFailure(problem));
    if (!VaultRules.areValidAnswers(answers)) {
      return left(
        const SecurityFailure(
          'Answer both questions (up to ${VaultRules.maxAnswerLength} '
          'characters).',
        ),
      );
    }
    return _repository.setPinAndAnswers(
      pin: pin,
      answers: [
        for (final answer in answers) VaultRules.normalizeAnswer(answer)!,
      ],
    );
  }
}

/// The 6-digit PIN typed on the vault's number pad.
final class CheckVaultPinUseCase {
  const CheckVaultPinUseCase(this._repository);

  final VaultRepository _repository;

  FutureResult<VaultCheck> call(String pin) async {
    if (!VaultRules.isValidPin(pin)) return right(const VaultCheck(ok: false));
    return _repository.verifyPin(pin);
  }
}

/// Forgot password, step 1: are the two answers right?
final class CheckVaultAnswersUseCase {
  const CheckVaultAnswersUseCase(this._repository);

  final VaultRepository _repository;

  FutureResult<VaultCheck> call(List<String> answers) async {
    if (!VaultRules.areValidAnswers(answers)) {
      return right(const VaultCheck(ok: false));
    }
    return _repository.verifyAnswers([
      for (final answer in answers) VaultRules.normalizeAnswer(answer)!,
    ]);
  }
}

/// Forgot password, step 2: a new PIN, allowed by the right answers.
final class ResetPinWithAnswersUseCase {
  const ResetPinWithAnswersUseCase(this._repository);

  final VaultRepository _repository;

  FutureResult<VaultCheck> call({
    required List<String> answers,
    required String pin,
    required String confirm,
  }) async {
    final problem = newPinProblem(pin, confirm);
    if (problem != null) return left(SecurityFailure(problem));
    if (!VaultRules.areValidAnswers(answers)) {
      return right(const VaultCheck(ok: false));
    }
    return _repository.setPinWithAnswers(
      answers: [
        for (final answer in answers) VaultRules.normalizeAnswer(answer)!,
      ],
      pin: pin,
    );
  }
}

/// Forgot PIN and answers: a new PIN, allowed by the Recovery Key.
final class ResetPinWithRecoveryKeyUseCase {
  const ResetPinWithRecoveryKeyUseCase(this._repository);

  final VaultRepository _repository;

  FutureResult<VaultCheck> call({
    required String recoveryKey,
    required String pin,
    required String confirm,
  }) async {
    final problem = newPinProblem(pin, confirm);
    if (problem != null) return left(SecurityFailure(problem));
    // Spaces / dashes do not count; the exact check is native.
    final letters = recoveryKey.replaceAll(RegExp('[^A-Za-z0-9]'), '');
    if (letters.length != VaultRules.recoveryKeyLength) {
      return left(
        const SecurityFailure(
          'A Recovery Key has ${VaultRules.recoveryKeyLength} letters and '
          'numbers.',
        ),
      );
    }
    return _repository.setPinWithRecoveryKey(
      recoveryKey: recoveryKey,
      pin: pin,
    );
  }
}
