import 'package:proalbums/core/utils/typedefs.dart';

/// Puts pictures on the system clipboard ("Copy to clipboard"), to paste in
/// another app.
abstract interface class MediaClipboardRepository {
  /// [ids] are media ids of PICTURES (videos cannot be copied).
  ///
  /// Success value: true when the system shows its own "Copied"
  /// confirmation (Android 13+), so the app must not show one too.
  FutureResult<bool> copyImages(List<String> ids);
}
