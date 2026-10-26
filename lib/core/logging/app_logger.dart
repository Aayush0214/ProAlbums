import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Tiny logger, no extra package needed.
///
/// Everything is silent in release builds on purpose: a gallery app handles
/// private media, so file names/paths must never end up in release logs.
abstract final class AppLogger {
  static const String _defaultTag = 'ProAlbums';

  static void d(String message, {String tag = _defaultTag}) {
    if (kDebugMode) developer.log(message, name: tag);
  }

  static void e(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String tag = _defaultTag,
  }) {
    if (kDebugMode) {
      developer.log(
        message,
        name: tag,
        level: 1000,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
