import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/vault/domain/repositories/vault_repository.dart';
import 'package:proalbums/features/vault/domain/vault_rules.dart';
import 'package:proalbums/features/vault/presentation/providers/vault_providers.dart';
import 'package:proalbums/features/vault/presentation/widgets/vault_secure_scope.dart';
import 'package:proalbums/shared/widgets/app_back_button.dart';

/// "Hidden photos" (opened only from Settings, after the check when the
/// password is on). Secure (no screenshots, blank in Recent apps).
///
/// Locks itself:
///  - when the page is left (the next visit asks again),
///  - 1 minute after the app went to the background ([VaultRules.autoLockAfter]):
///    coming back after that closes the page.
///
/// Phase 2: the page and its locking; the grid comes in phase 4.
class VaultPage extends ConsumerStatefulWidget {
  const VaultPage({super.key});

  @override
  ConsumerState<VaultPage> createState() => _VaultPageState();
}

class _VaultPageState extends ConsumerState<VaultPage> {
  late final VaultRepository _repository;
  late final AppLifecycleListener _lifecycle;
  DateTime? _wentAway;

  /// Wipes the key 1 minute after the app went away, even if it never
  /// comes back.
  Timer? _lockTimer;

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
    if (away == null) return;
    if (DateTime.now().difference(away) >= VaultRules.autoLockAfter &&
        mounted) {
      // Locked by dispose; back to Settings.
      context.pop();
    }
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    _lifecycle.dispose();
    _repository.lock();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VaultSecureScope(
      child: Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(),
          title: Text('Hidden photos', style: context.textTheme.titleLarge),
        ),
        body: Center(
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
                // Phase 3: only the count; the grid comes in phase 4.
                Text(switch (ref.watch(hiddenCountProvider).value ?? 0) {
                  0 => 'No hidden items',
                  1 => '1 hidden item',
                  final count => '$count hidden items',
                }, style: context.textTheme.titleMedium),
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
        ),
      ),
    );
  }
}
