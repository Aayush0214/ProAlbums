/// Result of creating the folder of a new album.
enum CreateFolderOutcome { created, alreadyExists }

/// Result of a Copy / Move into an album.
final class TransferResult {
  const TransferResult({
    required this.cancelled,
    this.done = 0,
    this.failed = 0,
  });

  /// The person said "no" in Android's permission dialog.
  final bool cancelled;
  final int done;
  final int failed;

  bool get allDone => !cancelled && failed == 0;
}

/// Progress of a Copy / Move: [done] of [total] files handled (copied,
/// moved or failed).
typedef TransferProgress = void Function(int done, int total);
