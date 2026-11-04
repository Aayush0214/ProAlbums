import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_row.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_rows_builder.dart';
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

/// Every hidden item (the vault page reads it while unlocked; dropped when
/// the page closes).
@riverpod
Future<List<VaultEntry>> vaultEntries(Ref ref) async {
  final result = await ref.read(vaultRepositoryProvider).list();
  return result.getOrElse((_) => const []);
}

/// Gallery ids of hidden items start with this, so they never mix with
/// real gallery ids (image cache, selection, viewer).
const String vaultIdPrefix = 'vault:';

/// The vault file id behind a vault MediaItem id.
String vaultFileId(String mediaId) => mediaId.startsWith(vaultIdPrefix)
    ? mediaId.substring(vaultIdPrefix.length)
    : mediaId;

/// The hidden items as the shared grid / viewer want them, newest first.
@riverpod
List<MediaItem> vaultMediaItems(Ref ref) {
  final entries = ref.watch(vaultEntriesProvider).value ?? const [];
  final items = [
    for (final entry in entries)
      MediaItem(
        id: '$vaultIdPrefix${entry.id}',
        type: entry.video ? MediaType.video : MediaType.image,
        createdAt: entry.createdAt,
        width: entry.width,
        height: entry.height,
        duration: entry.duration,
      ),
  ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return items;
}

/// The vault grid: a fixed 4 columns, no date headers (like the system
/// gallery's Hidden photos).
@riverpod
List<GalleryRow> vaultGalleryRows(Ref ref) => GalleryRowsBuilder.buildFlat(
  items: ref.watch(vaultMediaItemsProvider),
  columns: vaultGridColumns,
  alignToEnd: false,
);

const int vaultGridColumns = 4;
