import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:proalbums/core/error/failures.dart';
import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/vault/domain/entities/vault_status.dart';
import 'package:proalbums/features/vault/domain/repositories/vault_repository.dart';
import 'package:proalbums/features/vault/domain/usecases/vault_usecases.dart';
import 'package:proalbums/features/vault/domain/vault_rules.dart';

final class _FakeVault implements VaultRepository {
  final List<String> calls = [];

  @override
  FutureResult<Unit> setPinAndAnswers({
    required String pin,
    required List<String> answers,
  }) async {
    calls.add('setup $pin ${answers.join('|')}');
    return right(unit);
  }

  @override
  FutureResult<VaultCheck> verifyPin(String pin) async {
    calls.add('pin $pin');
    return right(VaultCheck(ok: pin == '123456'));
  }

  @override
  FutureResult<VaultCheck> verifyAnswers(List<String> answers) async {
    calls.add('answers ${answers.join('|')}');
    return right(const VaultCheck(ok: true));
  }

  @override
  FutureResult<VaultCheck> setPinWithAnswers({
    required List<String> answers,
    required String pin,
  }) async {
    calls.add('reset-answers ${answers.join('|')} $pin');
    return right(const VaultCheck(ok: true));
  }

  @override
  FutureResult<VaultCheck> setPinWithRecoveryKey({
    required String recoveryKey,
    required String pin,
  }) async {
    calls.add('reset-key $pin');
    return right(const VaultCheck(ok: true));
  }

  @override
  FutureResult<HideResult> hide(
    List<HideSource> items, {
    void Function(int done, int total)? onProgress,
  }) async {
    calls.add(
      'hide ${items.map((i) => '${i.id}:${i.video}:${i.favorite}').join(',')}',
    );
    onProgress?.call(items.length, items.length);
    return right(HideResult(hidden: items.length, failed: 0));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('VaultRules', () {
    test('PIN is exactly 6 digits', () {
      expect(VaultRules.isValidPin('123456'), isTrue);
      expect(VaultRules.isValidPin('12345'), isFalse);
      expect(VaultRules.isValidPin('1234567'), isFalse);
      expect(VaultRules.isValidPin('12345a'), isFalse);
      expect(VaultRules.isValidPin('12 456'), isFalse);
    });

    test('answers ignore case and extra spaces', () {
      expect(VaultRules.normalizeAnswer('  Tom  and Jerry '), 'tom and jerry');
      expect(VaultRules.normalizeAnswer('DOCTOR'), 'doctor');
      expect(VaultRules.normalizeAnswer('   '), isNull);
    });

    test('both answers, at most 15 characters each', () {
      expect(VaultRules.areValidAnswers(['doctor', 'shinchan']), isTrue);
      expect(VaultRules.areValidAnswers(['doctor']), isFalse);
      expect(VaultRules.areValidAnswers(['doctor', ' ']), isFalse);
      expect(VaultRules.areValidAnswers(['doctor', 'a' * 16]), isFalse);
      // Spaces at the ends do not count towards the limit.
      expect(VaultRules.areValidAnswers(['doctor', '  ${'a' * 15}  ']), isTrue);
    });

    test('two fixed questions', () {
      expect(VaultRules.questions, hasLength(2));
    });
  });

  group('use cases', () {
    test('setup sends the PIN and the normalized answers', () async {
      final vault = _FakeVault();
      final result = await SetUpVaultPasswordUseCase(vault)(
        pin: '123456',
        confirm: '123456',
        answers: [' Pilot ', 'Tom  and Jerry'],
      );
      expect(result.isRight(), isTrue);
      expect(vault.calls, ['setup 123456 pilot|tom and jerry']);
    });

    test(
      'setup refuses mismatched PINs, short PINs and missing answers',
      () async {
        final vault = _FakeVault();
        final setup = SetUpVaultPasswordUseCase(vault);
        Future<Failure?> problem(
          String pin,
          String confirm,
          List<String> a,
        ) async => (await setup(
          pin: pin,
          confirm: confirm,
          answers: a,
        )).getLeft().toNullable();
        expect(
          await problem('123456', '654321', ['a', 'b']),
          isA<SecurityFailure>(),
        );
        expect(
          await problem('1234', '1234', ['a', 'b']),
          isA<SecurityFailure>(),
        );
        expect(
          await problem('123456', '123456', ['a', '']),
          isA<SecurityFailure>(),
        );
        expect(vault.calls, isEmpty);
      },
    );

    test('a malformed PIN is a wrong PIN without asking the vault', () async {
      final vault = _FakeVault();
      final check = await CheckVaultPinUseCase(vault)('12');
      expect(check.getOrElse((_) => const VaultCheck(ok: true)).ok, isFalse);
      expect(vault.calls, isEmpty);
      final right = await CheckVaultPinUseCase(vault)('123456');
      expect(right.getOrElse((_) => const VaultCheck(ok: false)).ok, isTrue);
    });

    test('reset with answers normalizes them', () async {
      final vault = _FakeVault();
      await ResetPinWithAnswersUseCase(vault)(
        answers: ['PILOT', ' Shinchan'],
        pin: '111111',
        confirm: '111111',
      );
      expect(vault.calls, ['reset-answers pilot|shinchan 111111']);
    });

    test('reset with the Recovery Key needs 24 letters and numbers', () async {
      final vault = _FakeVault();
      final reset = ResetPinWithRecoveryKeyUseCase(vault);
      final bad = await reset(
        recoveryKey: 'ABCD-1234',
        pin: '111111',
        confirm: '111111',
      );
      expect(bad.isLeft(), isTrue);
      final good = await reset(
        recoveryKey: 'k7qm-2xpa-9rtd-4hnw-8bcf-3vze',
        pin: '111111',
        confirm: '111111',
      );
      expect(good.isRight(), isTrue);
      expect(vault.calls, ['reset-key 111111']);
    });
  });

  group('Hide', () {
    MediaItem item(String id, {bool video = false}) => MediaItem(
      id: id,
      type: video ? MediaType.video : MediaType.image,
      createdAt: DateTime(2026, 11, 4),
      width: 10,
      height: 10,
    );

    test('nothing to hide is refused without asking the vault', () async {
      final vault = _FakeVault();
      final result = await HideMediaUseCase(vault)([]);
      expect(result.isLeft(), isTrue);
      expect(vault.calls, isEmpty);
    });

    test('ids and kinds go to the vault, progress comes back', () async {
      final vault = _FakeVault();
      final seen = <(int, int)>[];
      final result = await HideMediaUseCase(vault)(
        [item('7'), item('9', video: true)],
        favorites: {'7', 'not-hidden'},
        onProgress: (done, total) => seen.add((done, total)),
      );
      expect(result.getOrElse((_) => const HideResult.cancelled()).hidden, 2);
      expect(vault.calls, ['hide 7:false:true,9:true:false']);
      expect(seen, [(2, 2)]);
    });
  });
}
