import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/vault/presentation/providers/vault_providers.dart';
import 'package:proalbums/features/vault/presentation/widgets/vault_secure_scope.dart';
import 'package:proalbums/shared/widgets/app_snack_bar.dart';

/// Shown ONCE, when the vault is made (first Hide or first privacy
/// password): what the Recovery Key is, when it is needed, how to keep it.
/// The person must tick "I have saved it" before leaving — the key is never
/// stored and can never be shown again. Pops true when confirmed.
class VaultRecoveryKeyPage extends ConsumerStatefulWidget {
  const VaultRecoveryKeyPage({required this.recoveryKey, super.key});

  final String recoveryKey;

  @override
  ConsumerState<VaultRecoveryKeyPage> createState() =>
      _VaultRecoveryKeyPageState();
}

class _VaultRecoveryKeyPageState extends ConsumerState<VaultRecoveryKeyPage> {
  bool _saved = false;

  Future<void> _copy() async {
    final toast = AppToast.of(context);
    final result = await ref
        .read(vaultRepositoryProvider)
        .copyRecoveryKey(widget.recoveryKey);
    result.match(
      (failure) => toast.show(failure.message),
      // Android 13+ shows its own "Copied".
      (systemConfirms) {
        if (!systemConfirms) toast.show('Copied');
      },
    );
  }

  Future<void> _continue() async {
    await ref.read(vaultRepositoryProvider).confirmRecoveryKeySaved();
    if (mounted) context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final secondary = context.textTheme.bodyMedium?.copyWith(
      color: context.colors.textSecondary,
    );
    final groups = widget.recoveryKey.split('-');
    return VaultSecureScope(
      child: PopScope(
        // Leaving without saving would lose the key for ever.
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            AppToast.of(context).show('Save your Recovery Key first');
          }
        },
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Text('Recovery Key', style: context.textTheme.titleLarge),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              Icon(
                LucideIcons.keyRound,
                size: 40,
                color: context.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Write down this key and keep it safe',
                style: context.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                'Your hidden photos and videos are locked (encrypted). '
                'This Recovery Key is the only way to get them back if:',
                style: secondary,
              ),
              const SizedBox(height: 8),
              for (final reason in const [
                'you uninstall ProAlbums or clear its data, and install it '
                    'again (your hidden items stay safely locked in the '
                    '"Documents/ProAlbums Vault" folder; do not delete it)',
                'you move to a new phone and copy that folder to it',
                'you forget your privacy password and the answers to your '
                    'security questions',
              ])
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('•  ', style: secondary),
                      Expanded(child: Text(reason, style: secondary)),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              _KeyBox(groups: groups),
              const SizedBox(height: 12),
              Center(
                child: TextButton.icon(
                  onPressed: _copy,
                  icon: const Icon(LucideIcons.copy, size: 18),
                  label: const Text('Copy'),
                ),
              ),
              const SizedBox(height: 16),
              Text('Keep it safe', style: context.textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final tip in const [
                'Write it on paper, or save it in a password manager.',
                'Do not keep it only on this phone: if the phone is lost, '
                    'the key is lost too.',
                'ProAlbums never stores this key and cannot show it again.',
                'Anyone who has this key and your vault folder can open your '
                    'hidden items, so do not share it.',
              ])
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('•  ', style: secondary),
                      Expanded(child: Text(tip, style: secondary)),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _saved,
                onChanged: (value) => setState(() => _saved = value ?? false),
                title: const Text('I have saved my Recovery Key'),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(shape: const StadiumBorder()),
                  onPressed: _saved ? _continue : null,
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The key in its six groups of four, large and easy to copy by hand.
class _KeyBox extends StatelessWidget {
  const _KeyBox({required this.groups});

  final List<String> groups;

  @override
  Widget build(BuildContext context) {
    // The theme's font (no I, L, O or U in a key, so nothing looks alike),
    // with even-width digits and some air between letters.
    final style = context.textTheme.titleLarge?.copyWith(
      letterSpacing: 2,
      fontWeight: FontWeight.w600,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.dividerSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        child: Semantics(
          label: 'Recovery Key ${groups.join(' ')}',
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 18,
            runSpacing: 14,
            children: [for (final group in groups) Text(group, style: style)],
          ),
        ),
      ),
    );
  }
}
