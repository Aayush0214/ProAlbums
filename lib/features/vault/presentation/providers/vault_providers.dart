import 'package:proalbums/features/vault/data/method_channel_vault_repository.dart';
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
