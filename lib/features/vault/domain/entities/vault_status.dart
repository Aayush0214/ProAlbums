/// Where the private vault stands on this phone.
final class VaultStatus {
  const VaultStatus({
    required this.created,
    required this.passwordEnabled,
    required this.hasPin,
    required this.recoveryKeySaved,
    required this.unlocked,
    required this.wait,
  });

  static const VaultStatus none = VaultStatus(
    created: false,
    passwordEnabled: false,
    hasPin: false,
    recoveryKeySaved: false,
    unlocked: false,
    wait: Duration.zero,
  );

  /// The vault exists (first Hide done, Recovery Key made).
  final bool created;

  /// "Password for hidden photos" is on: opening / hiding needs the PIN or a
  /// fingerprint.
  final bool passwordEnabled;

  /// A PIN and the two answers were set once.
  final bool hasPin;

  /// The person said they saved the Recovery Key.
  final bool recoveryKeySaved;

  /// The vault key is in memory right now.
  final bool unlocked;

  /// After too many wrong tries: how long until the next try is allowed.
  final Duration wait;

  @override
  bool operator ==(Object other) =>
      other is VaultStatus &&
      other.created == created &&
      other.passwordEnabled == passwordEnabled &&
      other.hasPin == hasPin &&
      other.recoveryKeySaved == recoveryKeySaved &&
      other.unlocked == unlocked &&
      other.wait == wait;

  @override
  int get hashCode => Object.hash(
    created,
    passwordEnabled,
    hasPin,
    recoveryKeySaved,
    unlocked,
    wait,
  );
}

/// The answer to a PIN / answers / Recovery Key check.
final class VaultCheck {
  const VaultCheck({required this.ok, this.wait = Duration.zero});

  final bool ok;

  /// Too many wrong tries: wait this long before the next one.
  final Duration wait;
}
