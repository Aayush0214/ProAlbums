import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proalbums/features/vault/domain/repositories/vault_repository.dart';
import 'package:proalbums/features/vault/presentation/providers/vault_providers.dart';

/// Wrap every vault screen and every security step (PIN card, setup,
/// Recovery Key, forgot password) in this: while at least one is on screen
/// the window is FLAG_SECURE — no screenshots, no screen recording, a blank
/// card in Recent apps (like banking apps). Counted, so a dialog over a
/// vault page (or the other way round) keeps it on until the last one goes.
class VaultSecureScope extends ConsumerStatefulWidget {
  const VaultSecureScope({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<VaultSecureScope> createState() => _VaultSecureScopeState();
}

class _VaultSecureScopeState extends ConsumerState<VaultSecureScope> {
  static int _open = 0;

  /// Kept from initState: ref cannot be used in dispose.
  late final VaultRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = ref.read(vaultRepositoryProvider);
    _open++;
    if (_open == 1) _repository.setSecure(secure: true);
  }

  @override
  void dispose() {
    _open--;
    if (_open == 0) _repository.setSecure(secure: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
