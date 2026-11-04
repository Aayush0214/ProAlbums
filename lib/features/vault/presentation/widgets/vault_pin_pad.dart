import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/vault/domain/vault_rules.dart';

/// The PIN as [VaultRules.pinLength] round dots: hollow, filled with the
/// primary colour as digits are typed. Digits are never shown.
class VaultPinDots extends StatelessWidget {
  const VaultPinDots({required this.filled, super.key});

  final int filled;

  @override
  Widget build(BuildContext context) {
    final primary = context.colorScheme.primary;
    final outline = context.colors.textSecondary;
    return Semantics(
      label: '$filled of ${VaultRules.pinLength} digits entered',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < VaultRules.pinLength; index++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: index < filled ? primary : Colors.transparent,
                  border: Border.all(
                    color: index < filled ? primary : outline,
                    width: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The vault's own number pad (not the phone keyboard):
///
///     1   2   3
///     4   5   6
///     7   8   9
///   Forgot  0  ⌫
///
/// ⌫ is off while nothing is typed; everything is off while [enabled] is
/// false (e.g. waiting after too many wrong tries).
class VaultPinPad extends StatelessWidget {
  const VaultPinPad({
    required this.onDigit,
    required this.onDelete,
    required this.canDelete,
    this.onForgot,
    this.enabled = true,
    super.key,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final bool canDelete;

  /// null = no "Forgot password" key.
  final VoidCallback? onForgot;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    Widget digit(String value) => _PadKey(
      onTap: enabled ? () => onDigit(value) : null,
      child: Text(value, style: context.textTheme.headlineMedium),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [for (final value in row) digit(value)],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _PadKey(
              onTap: onForgot,
              child: onForgot == null
                  ? const SizedBox.shrink()
                  : Text(
                      'Forgot\npassword',
                      textAlign: TextAlign.center,
                      style: context.textTheme.labelMedium?.copyWith(
                        color: context.colorScheme.primary,
                      ),
                    ),
            ),
            digit('0'),
            _PadKey(
              onTap: enabled && canDelete ? onDelete : null,
              semanticLabel: 'Delete',
              child: Icon(
                LucideIcons.delete,
                color: enabled && canDelete
                    ? context.colorScheme.onSurface
                    : context.colors.textSecondary.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PadKey extends StatelessWidget {
  const _PadKey({required this.child, this.onTap, this.semanticLabel});

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;

  static const double _size = 72;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      enabled: onTap != null,
      child: SizedBox(
        width: _size,
        height: _size,
        child: Material(
          type: MaterialType.transparency,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onTap!();
                  },
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
