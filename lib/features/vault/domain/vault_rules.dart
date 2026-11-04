/// The private vault's rules (PIN, security questions, Recovery Key).
abstract final class VaultRules {
  /// The privacy password is exactly this many digits.
  static const int pinLength = 6;

  /// The two fixed security questions (both must be answered).
  static const List<String> questions = [
    'What did you want to become when you were a child?',
    'What was the name of your favourite cartoon character?',
  ];

  /// Longest answer allowed (characters).
  static const int maxAnswerLength = 15;

  /// How long the vault stays open after the app goes to the background.
  static const Duration autoLockAfter = Duration(minutes: 1);

  /// Characters in a Recovery Key (shown in groups of 4: XXXX-XXXX-...).
  static const int recoveryKeyLength = 24;

  static bool isValidPin(String pin) =>
      pin.length == pinLength && RegExp(r'^\d+$').hasMatch(pin);

  /// An answer as it is stored and compared: spaces at the ends dropped,
  /// runs of spaces made one, small letters — so 'Doctor ' and 'doctor'
  /// are the same answer. null when nothing is left.
  static String? normalizeAnswer(String typed) {
    final answer = typed.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
    return answer.isEmpty ? null : answer;
  }

  /// Both answers given, each at most [maxAnswerLength] characters.
  static bool areValidAnswers(List<String> typed) =>
      typed.length == questions.length &&
      typed.every(
        (answer) =>
            normalizeAnswer(answer) != null &&
            answer.trim().length <= maxAnswerLength,
      );
}
