import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/vault/domain/vault_rules.dart';
import 'package:proalbums/features/vault/presentation/providers/vault_providers.dart';
import 'package:proalbums/features/vault/presentation/widgets/vault_secure_scope.dart';
import 'package:proalbums/shared/widgets/app_back_button.dart';
import 'package:proalbums/shared/widgets/app_snack_bar.dart';

/// Restore, step 2 (the folder is picked): the Recovery Key, then every
/// hidden item of that folder is copied into this vault (still encrypted)
/// with a progress bar. Pops true when something was restored.
class VaultRestorePage extends ConsumerStatefulWidget {
  const VaultRestorePage({required this.itemCount, super.key});

  /// Hidden files found in the picked folder.
  final int itemCount;

  @override
  ConsumerState<VaultRestorePage> createState() => _VaultRestorePageState();
}

class _VaultRestorePageState extends ConsumerState<VaultRestorePage> {
  final _key = TextEditingController();
  bool _busy = false;
  String? _error;
  (int, int)? _progress;

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  bool get _ready =>
      _key.text.replaceAll(RegExp('[^A-Za-z0-9]'), '').length ==
      VaultRules.recoveryKeyLength;

  Future<void> _restore() async {
    setState(() {
      _busy = true;
      _error = null;
      _progress = (0, widget.itemCount);
    });
    final toast = AppToast.of(context);
    final result = await ref
        .read(vaultRepositoryProvider)
        .importFromFolder(
          _key.text,
          onProgress: (done, total) {
            if (mounted) setState(() => _progress = (done, total));
          },
        );
    if (!mounted) return;
    result.match(
      (failure) => setState(() {
        _busy = false;
        _progress = null;
        _error = failure.message;
      }),
      (import) {
        if (import.wrongKey) {
          final seconds = import.wait.inSeconds;
          setState(() {
            _busy = false;
            _progress = null;
            _error = seconds > 0
                ? 'Too many tries. Try again in '
                      '${seconds >= 60 ? '${(seconds / 60).ceil()} min' : '$seconds s'}'
                : 'This Recovery Key does not open this vault';
          });
          return;
        }
        toast.show(
          import.failed == 0
              ? '${import.restored} hidden items restored'
              : '${import.restored} restored, ${import.failed} could not be',
        );
        context.pop(import.restored > 0);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final secondary = context.textTheme.bodyMedium?.copyWith(
      color: context.colors.textSecondary,
    );
    final progress = _progress;
    return VaultSecureScope(
      child: PopScope(
        // Not while files are being copied.
        canPop: !_busy,
        child: Scaffold(
          appBar: AppBar(
            leading: _busy ? null : const AppBackButton(),
            automaticallyImplyLeading: false,
            title: Text(
              'Restore hidden items',
              style: context.textTheme.titleLarge,
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              Text(
                widget.itemCount == 1
                    ? '1 hidden item found'
                    : '${widget.itemCount} hidden items found',
                style: context.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the Recovery Key you saved when the vault was made. '
                'Dashes and spaces do not matter.',
                style: secondary,
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _key,
                enabled: !_busy,
                onChanged: (_) => setState(() {}),
                enableSuggestions: false,
                autocorrect: false,
                enableIMEPersonalizedLearning: false,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9 -]')),
                  LengthLimitingTextInputFormatter(40),
                ],
                decoration: const InputDecoration(
                  labelText: 'Recovery Key',
                  hintText: 'XXXX-XXXX-XXXX-XXXX-XXXX-XXXX',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              if (progress != null) ...[
                LinearProgressIndicator(
                  value: progress.$2 == 0 ? null : progress.$1 / progress.$2,
                ),
                const SizedBox(height: 8),
                Text(
                  'Restoring ${progress.$1} / ${progress.$2}',
                  textAlign: TextAlign.end,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              SizedBox(
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(shape: const StadiumBorder()),
                  onPressed: _ready && !_busy ? _restore : null,
                  child: const Text('Restore'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
