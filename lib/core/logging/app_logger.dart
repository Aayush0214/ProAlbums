import 'package:flutter/foundation.dart';

/// Tiny logger, no extra package needed.
///
/// Prints in debug AND profile builds (so we can measure on a real phone),
/// but stays silent in release builds on purpose: a gallery app handles
/// private media, so file names/paths must never end up in release logs.
abstract final class AppLogger {
  static const String _defaultTag = 'ProAlbums';

  static void d(String message, {String tag = _defaultTag}) {
    if (!kReleaseMode) debugPrint('[$tag] $message');
  }

  static void e(
      String message, {
        Object? error,
        StackTrace? stackTrace,
        String tag = _defaultTag,
      }) {
    if (kReleaseMode) return;
    debugPrint('[$tag] ERROR: $message');
    if (error != null) debugPrint('[$tag] $error');
    if (stackTrace != null) debugPrint('$stackTrace');
  }
}