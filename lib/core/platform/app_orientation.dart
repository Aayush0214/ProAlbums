import 'package:flutter/services.dart';

/// Which way the screen may turn.
///
/// Rule of the app (same as the system gallery): everything stays PORTRAIT,
/// only the photo / video viewer turns with the phone.
abstract final class AppOrientation {
  static const MethodChannel _channel = MethodChannel(
    'com.aayush.proalbums/orientation',
  );

  /// The whole app. Call once at start (main) and when the viewer closes.
  static Future<void> lockPortrait() => SystemChrome.setPreferredOrientations(
    const [DeviceOrientation.portraitUp],
  );

  /// The viewer: turn with the phone's sensor, EVEN if the system auto-rotate
  /// switch is off (like the system gallery). On Android this is done by
  /// OrientationChannel.kt; elsewhere all four directions are allowed.
  static Future<void> allowRotation() async {
    try {
      await _channel.invokeMethod<void>('sensor');
    } on MissingPluginException {
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    } on PlatformException {
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
  }

  /// The viewer's rotate button: hold the screen [landscape] (either side) or
  /// portrait, whatever the phone does, until [allowRotation] or
  /// [lockPortrait] (the viewer closes).
  static Future<void> hold({required bool landscape}) =>
      SystemChrome.setPreferredOrientations(
        landscape
            ? const [
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ]
            : const [DeviceOrientation.portraitUp],
      );
}
