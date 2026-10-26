/// Every expected error in the app is a [Failure].
///
/// Rule: the DATA layer catches platform/database exceptions and converts them
/// to a Failure. DOMAIN and PRESENTATION never see raw exceptions, they only
/// see `Either<Failure, T>`.
///
/// `sealed` lets the compiler force us to handle every case in a `switch`
/// (for example when mapping a Failure to a user-facing message in the UI).
sealed class Failure {
  const Failure(this.message, {this.cause, this.stackTrace});

  /// Safe, short description (never put file paths or PINs in here).
  final String message;

  /// Original exception, kept only for logging/debugging.
  final Object? cause;
  final StackTrace? stackTrace;

  // Two failures are equal when they have the same type and message.
  // `cause` / `stackTrace` are ignored on purpose, so tests stay simple.
  @override
  bool operator ==(Object other) =>
      other is Failure &&
          other.runtimeType == runtimeType &&
          other.message == message;

  @override
  int get hashCode => Object.hash(runtimeType, message);

  @override
  String toString() => '$runtimeType($message)';
}

/// Gallery permission denied / limited / permanently denied.
final class PermissionFailure extends Failure {
  final bool isPermanentlyDenied;

  const PermissionFailure([
    super.message = 'Media permission was denied. Please grant access in Settings.',
    this.isPermanentlyDenied = false,
  ]) : super();

  const PermissionFailure.withDetails(
      super.message, {
        this.isPermanentlyDenied = false,
        super.cause,
        super.stackTrace,
      });
}

/// Reading or modifying media (photo_manager / MediaStore) failed.
final class MediaFailure extends Failure {
  const MediaFailure(super.message, {super.cause, super.stackTrace});
}

/// File system problems (copy to vault, low disk space, ...).
final class StorageFailure extends Failure {
  const StorageFailure(super.message, {super.cause, super.stackTrace});
}

/// Drift / SQLite problems.
final class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message, {super.cause, super.stackTrace});
}

/// PIN, biometric or encryption problems (vault).
final class SecurityFailure extends Failure {
  const SecurityFailure(super.message, {super.cause, super.stackTrace});
}

/// Anything we did not expect. Should be rare, always logged.
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message, {super.cause, super.stackTrace});
}
