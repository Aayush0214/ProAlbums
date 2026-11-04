import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/vault/domain/entities/vault_status.dart';
import 'package:proalbums/features/vault/domain/usecases/vault_usecases.dart';
import 'package:proalbums/features/vault/domain/vault_rules.dart';
import 'package:proalbums/features/vault/presentation/pages/vault_setup_page.dart';
import 'package:proalbums/features/vault/presentation/providers/vault_providers.dart';
import 'package:proalbums/features/vault/presentation/widgets/vault_secure_scope.dart';
import 'package:proalbums/shared/widgets/app_back_button.dart';
import 'package:proalbums/shared/widgets/app_snack_bar.dart';
import 'package:proalbums/shared/widgets/confirm_dialog.dart';

enum _Step { answers, newPin, recoveryKey }

/// Forgot password:
///  1. the two security questions → a new password;
///  2. forgot the answers too → the Recovery Key → a new password;
///  3. no Recovery Key either → Reset vault (everything hidden is deleted,
///     asked twice).
/// Pops true when a new password was set (the vault is then unlocked).
class VaultForgotPage extends ConsumerStatefulWidget {
  const VaultForgotPage({super.key});

  @override
  ConsumerState<VaultForgotPage> createState() => _VaultForgotPageState();
}

class _VaultForgotPageState extends ConsumerState<VaultForgotPage> {
  _Step _step = _Step.answers;
  final _answers = [TextEditingController(), TextEditingController()];
  final _recoveryKey = TextEditingController();
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [..._answers, _recoveryKey, _pin, _confirm]) {
      controller.dispose();
    }
    super.dispose();
  }

  List<String> get _answerTexts => [for (final a in _answers) a.text];

  String _checkFailed(VaultCheck check, String wrong) {
    if (check.wait > Duration.zero) {
      final seconds = check.wait.inSeconds + 1;
      return seconds >= 60
          ? 'Too many tries. Try again in ${(seconds / 60).ceil()} min'
          : 'Too many tries. Try again in $seconds s';
    }
    return wrong;
  }

  Future<void> _checkAnswers() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref.read(checkVaultAnswersUseCaseProvider)(
      _answerTexts,
    );
    if (!mounted) return;
    result.match(
      (failure) => setState(() => _error = failure.message),
      (check) => setState(() {
        if (check.ok) {
          _step = _Step.newPin;
        } else {
          _error = _checkFailed(check, 'The answers are not right');
        }
      }),
    );
    setState(() => _busy = false);
  }

  Future<void> _setPin() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = _step == _Step.recoveryKey
        ? await ref.read(resetPinWithRecoveryKeyUseCaseProvider)(
            recoveryKey: _recoveryKey.text,
            pin: _pin.text,
            confirm: _confirm.text,
          )
        : await ref.read(resetPinWithAnswersUseCaseProvider)(
            answers: _answerTexts,
            pin: _pin.text,
            confirm: _confirm.text,
          );
    if (!mounted) return;
    final toast = AppToast.of(context);
    result.match(
      (failure) => setState(() {
        _busy = false;
        _error = failure.message;
      }),
      (check) {
        if (check.ok) {
          toast.show('New password set');
          context.pop(true);
          return;
        }
        setState(() {
          _busy = false;
          _error = _checkFailed(
            check,
            _step == _Step.recoveryKey
                ? 'This Recovery Key does not match your vault'
                : 'The answers are not right',
          );
        });
      },
    );
  }

  Future<void> _reset() async {
    final first = await showConfirmDialog(
      context,
      title: 'Reset private vault?',
      message:
          'Without your password, your answers or your Recovery Key, the '
          'hidden photos and videos cannot be opened. Resetting deletes all '
          'of them for good and starts an empty vault.',
      confirmLabel: 'Reset',
    );
    if (!(first ?? false) || !mounted) return;
    final second = await showConfirmDialog(
      context,
      title: 'Delete all hidden items?',
      message: 'This cannot be undone.',
      confirmLabel: 'Delete all',
    );
    if (!(second ?? false) || !mounted) return;
    final toast = AppToast.of(context);
    final result = await ref.read(vaultRepositoryProvider).reset();
    await ref.read(vaultSessionProvider.notifier).refresh();
    if (!mounted) return;
    result.match((failure) => toast.show(failure.message), (_) {
      toast.show('Private vault was reset');
      context.pop(false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return VaultSecureScope(
      child: Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(),
          title: Text('Forgot password', style: context.textTheme.titleLarge),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            ...switch (_step) {
              _Step.answers => _answersStep(context),
              _Step.newPin => _newPinStep(context, withKey: false),
              _Step.recoveryKey => _newPinStep(context, withKey: true),
            },
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  TextStyle? get _secondary => context.textTheme.bodySmall?.copyWith(
    color: context.colors.textSecondary,
  );

  List<Widget> _answersStep(BuildContext context) {
    final ready = VaultRules.areValidAnswers(_answerTexts);
    return [
      Text(
        'Answer your security questions',
        style: context.textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      Text('Not case-sensitive; extra spaces are ignored.', style: _secondary),
      for (var index = 0; index < VaultRules.questions.length; index++) ...[
        const SizedBox(height: 18),
        Text(VaultRules.questions[index], style: context.textTheme.bodyLarge),
        const SizedBox(height: 8),
        AnswerField(
          controller: _answers[index],
          onChanged: (_) => setState(() {}),
        ),
      ],
      const SizedBox(height: 20),
      SizedBox(
        height: 48,
        child: FilledButton(
          style: FilledButton.styleFrom(shape: const StadiumBorder()),
          onPressed: ready && !_busy ? _checkAnswers : null,
          child: const Text('Next'),
        ),
      ),
      const SizedBox(height: 24),
      TextButton(
        onPressed: () => setState(() {
          _step = _Step.recoveryKey;
          _error = null;
        }),
        child: const Text('Forgot the answers? Use your Recovery Key'),
      ),
      TextButton(
        style: TextButton.styleFrom(foregroundColor: context.colorScheme.error),
        onPressed: _busy ? null : _reset,
        child: const Text('No Recovery Key? Reset vault'),
      ),
    ];
  }

  List<Widget> _newPinStep(BuildContext context, {required bool withKey}) {
    final keyReady =
        !withKey ||
        _recoveryKey.text.replaceAll(RegExp('[^A-Za-z0-9]'), '').length ==
            VaultRules.recoveryKeyLength;
    final ready = keyReady && newPinProblem(_pin.text, _confirm.text) == null;
    return [
      Text(
        withKey ? 'Use your Recovery Key' : 'Set a new password',
        style: context.textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      Text(
        withKey
            ? 'Type the ${VaultRules.recoveryKeyLength}-character key you saved '
                  'when the vault was made (dashes and spaces do not matter), '
                  'then a new password.'
            : 'Your answers are right. Choose a new '
                  '${VaultRules.pinLength}-digit password.',
        style: _secondary,
      ),
      if (withKey) ...[
        const SizedBox(height: 18),
        TextField(
          controller: _recoveryKey,
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
      ],
      const SizedBox(height: 18),
      PinField(
        controller: _pin,
        label: 'New password',
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 12),
      PinField(
        controller: _confirm,
        label: 'Confirm password',
        errorText:
            _confirm.text.length == VaultRules.pinLength &&
                _pin.text != _confirm.text
            ? 'The passwords do not match'
            : null,
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 24),
      SizedBox(
        height: 48,
        child: FilledButton(
          style: FilledButton.styleFrom(shape: const StadiumBorder()),
          onPressed: ready && !_busy ? _setPin : null,
          child: const Text('Set password'),
        ),
      ),
      if (withKey) ...[
        const SizedBox(height: 24),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: context.colorScheme.error,
          ),
          onPressed: _busy ? null : _reset,
          child: const Text('No Recovery Key? Reset vault'),
        ),
      ],
    ];
  }
}
