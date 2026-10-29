import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'shared_preferences_provider.g.dart';

/// Provider for accessing SharedPreferences synchronously.
///
/// Note: Its body intentionally throws an error!
/// Since SharedPreferences.getInstance() returns a Future, we
/// want to avoid having to 'await' it everywhere or causing the
/// UI to flicker while the theme loads.
///
/// Solution: We load the instance beforehand in bootstrap.dart
/// and inject it here using ProviderScope(overrides: [...]).
/// This ensures the provider offers a ready-to-use synchronous value throughout the app.
///
/// If the override is ever forgotten, this UnimplementedError will cause
/// an immediate crash—a loud failure rather than a silent bug. This is intentional.

@Riverpod(keepAlive: true)
SharedPreferences sharedPreferences(Ref ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in ProviderScope.',
  );
}