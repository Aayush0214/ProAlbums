import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/vault/domain/usecases/vault_usecases.dart';
import 'package:proalbums/features/vault/domain/vault_rules.dart';
import 'package:proalbums/features/vault/presentation/providers/vault_providers.dart';
import 'package:proalbums/features/vault/presentation/widgets/vault_secure_scope.dart';
import 'package:proalbums/shared/widgets/app_back_button.dart';

/// Turning "Password for hidden photos" on the first time: a 6-digit
/// privacy password (typed twice) and the two security questions, all on
/// one screen. Pops true when saved.
class VaultSetupPage extends ConsumerStatefulWidget {
  const VaultSetupPage({super.key});

  @override
  ConsumerState<VaultSetupPage> createState() => _VaultSetupPageState();
}

class _VaultSetupPageState extends ConsumerState<VaultSetupPage> {
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  final _answers = [TextEditingController(), TextEditingController()];
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    _confirm.dispose();
    for (final answer in _answers) {
      answer.dispose();
    }
    super.dispose();
  }

  bool get _ready =>
      newPinProblem(_pin.text, _confirm.text) == null &&
      VaultRules.areValidAnswers([for (final a in _answers) a.text]);

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await ref.read(setUpVaultPasswordUseCaseProvider)(
      pin: _pin.text,
      confirm: _confirm.text,
      answers: [for (final answer in _answers) answer.text],
    );
    if (!mounted) return;
    result.match(
      (failure) => setState(() {
        _saving = false;
        _error = failure.message;
      }),
      (_) => context.pop(true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final secondary = context.textTheme.bodySmall?.copyWith(
      color: context.colors.textSecondary,
    );
    final mismatch =
        _confirm.text.length == VaultRules.pinLength &&
        _pin.text != _confirm.text;
    return VaultSecureScope(
      child: Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(),
          title: Text('Privacy password', style: context.textTheme.titleLarge),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            Text(
              'Set a password for hidden photos',
              style: context.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Use ${VaultRules.pinLength} digits. You will need it to open '
              'Hidden photos and to hide items.',
              style: secondary,
            ),
            const SizedBox(height: 20),
            PinField(
              controller: _pin,
              label: 'New password',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            PinField(
              controller: _confirm,
              label: 'Confirm password',
              errorText: mismatch ? 'The passwords do not match' : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 32),
            Text('Security questions', style: context.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'If you forget your password, answering these lets you set a '
              'new one.',
              style: secondary,
            ),
            for (
              var index = 0;
              index < VaultRules.questions.length;
              index++
            ) ...[
              const SizedBox(height: 18),
              Text(
                VaultRules.questions[index],
                style: context.textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              AnswerField(
                controller: _answers[index],
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  LucideIcons.info,
                  size: 16,
                  color: context.colors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Answers are not case-sensitive and extra spaces are '
                    'ignored, but type the same words when you reset your '
                    'password. Up to ${VaultRules.maxAnswerLength} characters.',
                    style: secondary,
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 28),
            SizedBox(
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(shape: const StadiumBorder()),
                onPressed: _ready && !_saving ? _save : null,
                child: const Text('Set password'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A 6-digit password box: number keyboard, digits only, hidden by default
/// with an eye button to show it.
class PinField extends StatefulWidget {
  const PinField({
    required this.controller,
    required this.label,
    this.errorText,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  @override
  State<PinField> createState() => _PinFieldState();
}

class _PinFieldState extends State<PinField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      onChanged: widget.onChanged,
      obscureText: !_visible,
      keyboardType: TextInputType.number,
      // Never offered to the keyboard's suggestions / autofill.
      enableSuggestions: false,
      autocorrect: false,
      enableIMEPersonalizedLearning: false,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(VaultRules.pinLength),
      ],
      decoration: InputDecoration(
        labelText: widget.label,
        errorText: widget.errorText,
        suffixIcon: IconButton(
          tooltip: _visible ? 'Hide password' : 'Show password',
          icon: Icon(_visible ? LucideIcons.eyeOff : LucideIcons.eye),
          onPressed: () => setState(() => _visible = !_visible),
        ),
      ),
    );
  }
}

/// A security answer box: at most [VaultRules.maxAnswerLength] characters,
/// no suggestions or learning by the keyboard.
class AnswerField extends StatelessWidget {
  const AnswerField({
    required this.controller,
    this.onChanged,
    this.label = 'Your answer',
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      maxLength: VaultRules.maxAnswerLength,
      enableSuggestions: false,
      autocorrect: false,
      enableIMEPersonalizedLearning: false,
      textCapitalization: TextCapitalization.none,
      decoration: InputDecoration(labelText: label),
    );
  }
}
