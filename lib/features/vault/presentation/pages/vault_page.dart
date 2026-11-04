import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/albums/presentation/widgets/album_selection_widgets.dart';
import 'package:proalbums/features/gallery/domain/entities/media_details.dart';
import 'package:proalbums/features/gallery/presentation/actions/media_actions.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_grid.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_grid_skeleton.dart';
import 'package:proalbums/features/gallery/presentation/images/media_thumbnail_image.dart';
import 'package:proalbums/features/gallery/presentation/providers/media_selection.dart';
import 'package:proalbums/features/gallery/presentation/widgets/selection_action_bar.dart';
import 'package:proalbums/features/vault/domain/repositories/vault_repository.dart';
import 'package:proalbums/features/vault/domain/vault_rules.dart';
import 'package:proalbums/features/vault/presentation/providers/vault_providers.dart';
import 'package:proalbums/features/vault/presentation/widgets/vault_secure_scope.dart';
import 'package:proalbums/shared/widgets/app_back_button.dart';
import 'package:proalbums/shared/widgets/collapsing_sliver_app_bar.dart';

/// "Hidden photos" (opened only from Settings, after the check when the
/// password is on), on the SHARED grid with the vault context: a fixed 4
/// columns, no zoom, no date headers; select → Unhide / Delete (and ⤢ to
/// open); a tap opens the shared viewer with only Unhide / Delete.
///
/// Secure (no screenshots, blank in Recent apps). Pictures are decrypted
/// in memory only, and dropped from the image cache when the page closes.
/// Locks itself when left, and 1 minute after the app went to the
/// background ([VaultRules.autoLockAfter]): coming back after that closes
/// the vault (and its viewer).
class VaultPage extends ConsumerStatefulWidget {
  const VaultPage({super.key});

  @override
  ConsumerState<VaultPage> createState() => _VaultPageState();
}

class _VaultPageState extends ConsumerState<VaultPage> {
  final ScrollController _scroll = ScrollController();
  late final VaultRepository _repository;
  late final AppLifecycleListener _lifecycle;
  DateTime? _wentAway;

  /// Wipes the key 1 minute after the app went away, even if it never
  /// comes back.
  Timer? _lockTimer;

  /// Every (id, size) decoded from the vault, to drop from the image cache.
  final Set<(String, int)> _loaded = {};

  static final MediaSelectionControllerProvider _selectionProvider =
      mediaSelectionControllerProvider(MediaScope.vault);

  MediaSelectionController get _selection =>
      ref.read(_selectionProvider.notifier);

  @override
  void initState() {
    super.initState();
    _repository = ref.read(vaultRepositoryProvider);
    _lifecycle = AppLifecycleListener(onHide: _wentAwayNow, onShow: _cameBack);
  }

  void _wentAwayNow() {
    _wentAway ??= DateTime.now();
    _lockTimer ??= Timer(VaultRules.autoLockAfter, _repository.lock);
  }

  void _cameBack() {
    _lockTimer?.cancel();
    _lockTimer = null;
    final away = _wentAway;
    _wentAway = null;
    if (away == null || !mounted) return;
    if (DateTime.now().difference(away) >= VaultRules.autoLockAfter) {
      // Close the viewer too (if open), then this page: locked by dispose.
      final route = ModalRoute.of(context);
      Navigator.of(context).popUntil((other) => other == route);
      Navigator.of(context).maybePop();
    }
  }

  /// Small pictures for the grid, the big one for the viewer.
  Future<Uint8List?> _load(String id, int size) {
    _loaded.add((id, size));
    final fileId = vaultFileId(id);
    return size <= 512
        ? _repository.thumbnail(fileId)
        : _repository.picture(fileId, maxLongEdge: size);
  }

  /// The Info card: name, size, resolution — never where it is.
  Future<MediaDetails?> _details(String id) async {
    final details = await _repository.details(vaultFileId(id));
    if (details == null) return null;
    return MediaDetails(
      name: details.name,
      path: '',
      width: details.width,
      height: details.height,
      sizeBytes: details.sizeBytes,
    );
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    _lifecycle.dispose();
    _scroll.dispose();
    // Nothing decrypted stays in memory once the vault is closed.
    for (final (id, size) in _loaded) {
      MediaThumbnailImage(id: id, size: size, load: _load).evict();
    }
    _repository.lock();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(vaultEntriesProvider);
    final items = ref.watch(vaultMediaItemsProvider);
    final selecting = ref.watch(_selectionProvider.select((s) => s.active));
    // The vault's bars stand out from its grid (they are controls).
    final barColor = context.colors.surfaceContainerHigh;

    final Widget header = selecting
        ? Consumer(
            builder: (context, ref, _) {
              final count = ref.watch(
                _selectionProvider.select((s) => s.count),
              );
              return AlbumSelectionHeader(
                selectedCount: count,
                itemCount: items.length,
                onSelectAllToggle: () => count == items.length
                    ? _selection.clearSelection()
                    : _selection.selectAll([for (final i in items) i.id]),
                onClose: _selection.exit,
                backgroundColor: barColor,
              );
            },
          )
        : CollapsingSliverAppBar(
            title: 'Hidden photos',
            leading: const AppBackButton(),
            backgroundColor: barColor,
            actions: [
              if (items.isNotEmpty)
                IconButton(
                  tooltip: 'Select',
                  icon: const Icon(LucideIcons.squareCheck),
                  onPressed: _selection.start,
                ),
            ],
          );

    return VaultSecureScope(
      child: MediaScope(
        id: MediaScope.vault,
        mediaContext: MediaContext.vault,
        items: vaultMediaItemsProvider,
        thumbnailLoader: _load,
        detailsLoader: _details,
        // Played through the vault's 127.0.0.1 server, decrypted as it
        // plays; the address dies when the vault locks.
        videoSource: (item) async {
          final url = await _repository.videoUrl(vaultFileId(item.id));
          return url.fold((_) => null, (address) => address);
        },
        child: PopScope(
          // Back while selecting = leave select mode, not the vault.
          canPop: !selecting,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) _selection.exit();
          },
          child: Scaffold(
            bottomNavigationBar: selecting
                ? SelectionActionBar(backgroundColor: barColor)
                : null,
            body: items.isEmpty
                ? CustomScrollView(
                    slivers: [
                      header,
                      if (entries.isLoading)
                        const SliverGalleryGridSkeleton(
                          columns: vaultGridColumns,
                        )
                      else
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: _EmptyVault(),
                        ),
                    ],
                  )
                : GalleryGrid(
                    controller: _scroll,
                    rows: ref.watch(vaultGalleryRowsProvider),
                    items: items,
                    columns: vaultGridColumns,
                    reversed: false,
                    viewerItems: vaultMediaItemsProvider,
                    thumbTopInset:
                        MediaQuery.paddingOf(context).top + kToolbarHeight + 8,
                    leadingSlivers: [header],
                    // A fixed 4 columns, like the system gallery.
                    onZoomIn: () {},
                    onZoomOut: () {},
                  ),
          ),
        ),
      ),
    );
  }
}

class _EmptyVault extends StatelessWidget {
  const _EmptyVault();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.eyeOff,
              size: 48,
              color: context.colors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text('No hidden items', style: context.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Photos and videos you hide appear here, encrypted.',
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
