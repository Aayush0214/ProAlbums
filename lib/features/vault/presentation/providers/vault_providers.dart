import 'package:proalbums/features/vault/data/method_channel_vault_repository.dart';
import 'package:proalbums/features/vault/data/native_vault_biometrics.dart';
import 'package:proalbums/features/vault/domain/entities/vault_status.dart';
import 'package:proalbums/features/vault/domain/repositories/vault_repository.dart';
import 'package:proalbums/features/vault/domain/usecases/vault_usecases.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'vault_providers.g.dart';

@Riverpod(keepAlive: true)
VaultRepository vaultRepository(Ref ref) =>
    const MethodChannelVaultRepository();

@Riverpod(keepAlive: true)
SetUpVaultPasswordUseCase setUpVaultPasswordUseCase(Ref ref) =>
    SetUpVaultPasswordUseCase(ref.watch(vaultRepositoryProvider));

@Riverpod(keepAlive: true)
CheckVaultPinUseCase checkVaultPinUseCase(Ref ref) =>
    CheckVaultPinUseCase(ref.watch(vaultRepositoryProvider));

@Riverpod(keepAlive: true)
CheckVaultAnswersUseCase checkVaultAnswersUseCase(Ref ref) =>
    CheckVaultAnswersUseCase(ref.watch(vaultRepositoryProvider));

@Riverpod(keepAlive: true)
ResetPinWithAnswersUseCase resetPinWithAnswersUseCase(Ref ref) =>
    ResetPinWithAnswersUseCase(ref.watch(vaultRepositoryProvider));

@Riverpod(keepAlive: true)
ResetPinWithRecoveryKeyUseCase resetPinWithRecoveryKeyUseCase(Ref ref) =>
    ResetPinWithRecoveryKeyUseCase(ref.watch(vaultRepositoryProvider));

@Riverpod(keepAlive: true)
VaultBiometrics vaultBiometrics(Ref ref) => const NativeVaultBiometrics();

/// Where the vault stands (Settings switch, which card to show...).
/// [refresh] after every change.
@Riverpod(keepAlive: true)
class VaultSession extends _$VaultSession {
  @override
  Future<VaultStatus> build() async {
    final result = await ref.read(vaultRepositoryProvider).status();
    return result.getOrElse((_) => VaultStatus.none);
  }

  Future<VaultStatus> refresh() async {
    final result = await ref.read(vaultRepositoryProvider).status();
    final status = result.getOrElse((_) => VaultStatus.none);
    state = AsyncData(status);
    return status;
  }
}

@Riverpod(keepAlive: true)
HideMediaUseCase hideMediaUseCase(Ref ref) =>
    HideMediaUseCase(ref.watch(vaultRepositoryProvider));

/// How many items are hidden (the vault page; refreshed after a Hide).
@riverpod
Future<int> hiddenCount(Ref ref) async {
  final result = await ref.read(vaultRepositoryProvider).count();
  return result.getOrElse((_) => 0);
}
