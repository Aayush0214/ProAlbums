import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proalbums/app/app.dart';
import 'package:proalbums/core/logging/app_logger.dart';
import 'package:proalbums/core/storage/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  // 1) Error hooks FIRST: nothing can fail silently after this line.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppLogger.e('Flutter framework error',
        error: details.exception, stackTrace: details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.e('Uncaught async error', error: error, stackTrace: stack);
    return true;
  };

  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.d('boot: binding ready');

  try {
    // Result not needed, so we do not wait for it.
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    // Initialize MediaKit for hardware-accelerated 4K video playback
    // TODO(phase-3)
    // MediaKit.ensureInitialized();
    final prefs = await SharedPreferences.getInstance();
    AppLogger.d('boot: prefs ready');

    runApp(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const ProAlbumApp(),
      ),
    );
    AppLogger.d('boot: runApp called');
  } catch (error, stack) {
    AppLogger.e('Boot failed', error: error, stackTrace: stack);
    runApp(_BootErrorApp(message: kDebugMode ? '$error' : 'Please restart the app.'));
  }
}

/// Shown instead of a blank screen if startup itself fails.
class _BootErrorApp extends StatelessWidget {
  const _BootErrorApp({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ),
    ),
  );
}