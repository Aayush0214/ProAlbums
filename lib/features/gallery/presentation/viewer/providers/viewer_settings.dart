import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proalbums/core/platform/app_orientation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'viewer_settings.g.dart';

/// How the viewer turns with the phone (Settings > "Auto-rotate when
/// viewing photos").
enum ViewerRotation {
  /// Turns sideways with the phone (the default).
  always('Always'),

  /// Stays upright (the rotate buttons still turn it on purpose).
  never('Never');

  const ViewerRotation(this.label);

  final String label;
}

Future<bool> _readBool(String key, bool fallback) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? fallback;
  } on Object {
    return fallback;
  }
}

Future<void> _writeBool(String key, bool value) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  } on Object {
    // Back to the default next time.
  }
}

/// Settings > "Autoplay Videos": a video starts by itself (muted) when the
/// viewer rests on it. Off by default.
@Riverpod(keepAlive: true)
class ViewerAutoplay extends _$ViewerAutoplay {
  static const String _key = 'viewer_autoplay';

  @override
  Future<bool> build() => _readBool(_key, false);

  Future<void> save({required bool on}) async {
    state = AsyncData(on);
    await _writeBool(_key, on);
  }
}

/// Settings > "Keep screen on while viewing": the screen does not dim while
/// the viewer is open. Off by default (a playing video keeps it on anyway).
@Riverpod(keepAlive: true)
class ViewerKeepScreenOn extends _$ViewerKeepScreenOn {
  static const String _key = 'viewer_keep_screen_on';

  @override
  Future<bool> build() => _readBool(_key, false);

  Future<void> save({required bool on}) async {
    state = AsyncData(on);
    await _writeBool(_key, on);
  }
}

/// Settings > "Auto-rotate when viewing photos". Always by default.
@Riverpod(keepAlive: true)
class ViewerAutoRotate extends _$ViewerAutoRotate {
  static const String _key = 'viewer_auto_rotate';

  @override
  Future<ViewerRotation> build() async => await _readBool(_key, true)
      ? ViewerRotation.always
      : ViewerRotation.never;

  Future<void> save(ViewerRotation rotation) async {
    state = AsyncData(rotation);
    await _writeBool(_key, rotation == ViewerRotation.always);
  }
}

/// Turns the viewer with the phone or keeps it upright, as set (used when
/// the viewer opens and when the video player / slideshow give it back).
Future<void> applyViewerRotation(WidgetRef ref) async {
  final rotation =
      ref.read(viewerAutoRotateProvider).value ??
      await ref.read(viewerAutoRotateProvider.future);
  await applyRotation(rotation);
}

/// [rotation] applied (null = Always, the default).
Future<void> applyRotation(ViewerRotation? rotation) =>
    rotation == ViewerRotation.never
    ? AppOrientation.lockPortrait()
    : AppOrientation.allowRotation();
