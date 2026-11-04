import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/app/router/app_routes.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/vault/domain/repositories/vault_repository.dart';
import 'package:proalbums/features/vault/domain/vault_rules.dart';
import 'package:proalbums/features/vault/presentation/providers/vault_providers.dart';
import 'package:proalbums/features/vault/presentation/widgets/vault_pin_pad.dart';
import 'package:proalbums/features/vault/presentation/widgets/vault_secure_scope.dart';

/// How the PIN card was left.
enum _PinCardResult { unlocked, closed, useFingerprint }

/// The vault's check (opening Hidden photos, Hide, the password switch).
/// Only ONE dialog at a time:
///  1. phone with a fingerprint: the system sheet alone ("Verify
///     fingerprint", button "Use password");
///  2. "Use password" (or a fingerprint error / no fingerprint): the PIN
///     card with the vault's own number pad; its "Fingerprint verification"
///     closes it and goes back to 1.
/// Back / tap outside / X close everything. true = verified, vault unlocked.
Future<bool> showVaultAuthDialog(BuildContext context, WidgetRef ref) async {
  final biometrics = ref.read(vaultBiometricsProvider);
  final repository = ref.read(vaultRepositoryProvider);
  final hasFingerprint = await biometrics.available();
  var tryFingerprint = hasFingerprint;

  while (context.mounted) {
    if (tryFingerprint) {
      switch (await biometrics.authenticate()) {
        case BiometricResult.success:
          final unlocked = await repository.unlockAfterBiometric();
          return unlocked.getOrElse((_) => false);
        case BiometricResult.cancelled:
          return false;
        case BiometricResult.usePassword:
        case BiometricResult.error:
          break;
      }
    }
    if (!context.mounted) return false;
    final result = await showDialog<_PinCardResult>(
      context: context,
      useRootNavigator: true,
      builder: (context) => _PinCard(canUseFingerprint: hasFingerprint),
    );
    switch (result) {
      case _PinCardResult.unlocked:
        return true;
      case _PinCardResult.useFingerprint:
        tryFingerprint = true;
      case _PinCardResult.closed:
      case null:
        return false;
    }
  }
  return false;
}

class _PinCard extends ConsumerStatefulWidget {
  const _PinCard({required this.canUseFingerprint});

  final bool canUseFingerprint;

  @override
  ConsumerState<_PinCard> createState() => _PinCardState();
}

class _PinCardState extends ConsumerState<_PinCard> {
  String _pin = '';
  String? _message;
  bool _checking = false;

  /// Too many wrong tries: when the next one is allowed.
  DateTime? _waitUntil;
  Timer? _waitTicker;

  @override
  void initState() {
    super.initState();
    // A wait left over from earlier tries shows at once.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final status = await ref.read(vaultSessionProvider.notifier).refresh();
      if (mounted && status.wait > Duration.zero) {
        setState(() => _startWait(status.wait));
      }
    });
  }

  @override
  void dispose() {
    _waitTicker?.cancel();
    super.dispose();
  }

  void _leave(_PinCardResult result) => Navigator.of(context).pop(result);

  bool get _waiting =>
      _waitUntil != null && DateTime.now().isBefore(_waitUntil!);

  void _startWait(Duration wait) {
    _waitUntil = DateTime.now().add(wait);
    _waitTicker?.cancel();
    _waitTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (!_waiting) {
        timer.cancel();
        _waitUntil = null;
        setState(() => _message = null);
      } else {
        setState(() => _message = _waitText());
      }
    });
    _message = _waitText();
  }

  String _waitText() {
    final seconds = _waitUntil!.difference(DateTime.now()).inSeconds + 1;
    return seconds >= 60
        ? 'Too many tries. Try again in ${(seconds / 60).ceil()} min'
        : 'Too many tries. Try again in $seconds s';
  }

  Future<void> _digit(String digit) async {
    if (_checking || _waiting || _pin.length >= VaultRules.pinLength) return;
    setState(() {
      _pin += digit;
      _message = null;
    });
    if (_pin.length < VaultRules.pinLength) return;
    setState(() => _checking = true);
    final result = await ref.read(checkVaultPinUseCaseProvider)(_pin);
    if (!mounted) return;
    result.match(
      (failure) => setState(() {
        _checking = false;
        _pin = '';
        _message = failure.message;
      }),
      (check) {
        if (check.ok) {
          _leave(_PinCardResult.unlocked);
          return;
        }
        setState(() {
          _checking = false;
          _pin = '';
          if (check.wait > Duration.zero) {
            _startWait(check.wait);
          } else {
            _message = 'Wrong password';
          }
        });
      },
    );
  }

  /// Forgot password: true = a new password was set (vault unlocked);
  /// false = the vault was reset (nothing to open: close the card);
  /// null = came back (stay).
  Future<void> _forgot() async {
    final outcome = await context.push<bool>(AppRoutes.vaultForgot);
    if (!mounted || outcome == null) return;
    _leave(outcome ? _PinCardResult.unlocked : _PinCardResult.closed);
  }

  @override
  Widget build(BuildContext context) {
    return VaultSecureScope(
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (widget.canUseFingerprint)
                    TextButton(
                      onPressed: () => _leave(_PinCardResult.useFingerprint),
                      child: const Text('Fingerprint verification'),
                    )
                  else
                    const SizedBox(width: 48),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(LucideIcons.x),
                    onPressed: () => _leave(_PinCardResult.closed),
                  ),
                ],
              ),
              Text(
                'Enter privacy password',
                style: context.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              VaultPinDots(filled: _pin.length),
              SizedBox(
                height: 32,
                child: Center(
                  child: Text(
                    _message ?? '',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.error,
                    ),
                  ),
                ),
              ),
              VaultPinPad(
                enabled: !_checking && !_waiting,
                canDelete: _pin.isNotEmpty,
                onDigit: _digit,
                onDelete: () =>
                    setState(() => _pin = _pin.substring(0, _pin.length - 1)),
                onForgot: _forgot,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
