import 'package:proalbums/core/logging/app_logger.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the screen on (no dimming, no lock) while something plays.
abstract final class ScreenAwake {
  static Future<void> keepOn({required bool on}) async {
    try {
      await WakelockPlus.toggle(enable: on);
    } on Object catch (error, stackTrace) {
      // Never let a wakelock problem stop the video.
      AppLogger.e('Wakelock failed', error: error, stackTrace: stackTrace);
    }
  }
}
