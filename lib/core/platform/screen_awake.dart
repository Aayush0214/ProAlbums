import 'package:flutter/foundation.dart';
import 'package:proalbums/core/logging/app_logger.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the screen on (no dimming, no lock) while something needs it. Each
/// caller says who it is ([by]): the screen stays on while ANY of them wants
/// it (a video pausing must not turn it off while the viewer's "Keep screen
/// on while viewing" wants it on).
abstract final class ScreenAwake {
  static final Set<String> _holders = {};

  /// Who wants the screen on now.
  @visibleForTesting
  static Set<String> get holders => Set.unmodifiable(_holders);

  static Future<void> keepOn({required bool on, String by = 'app'}) async {
    final before = _holders.isNotEmpty;
    on ? _holders.add(by) : _holders.remove(by);
    final after = _holders.isNotEmpty;
    if (before == after) return;
    try {
      await WakelockPlus.toggle(enable: after);
    } on Object catch (error, stackTrace) {
      // Never let a wakelock problem stop the video.
      AppLogger.e('Wakelock failed', error: error, stackTrace: stackTrace);
    }
  }
}
