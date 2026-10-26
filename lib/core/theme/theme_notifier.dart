import 'package:flutter/material.dart';
import 'package:proalbums/core/storage/shared_preferences_provider.dart';
import 'package:proalbums/core/storage/storage_keys.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'theme_notifier.g.dart';

@Riverpod(keepAlive: true)
class ThemeModeNotifier extends _$ThemeModeNotifier {
  @override
  ThemeMode build() {
    // Load saved preferences as soon as the app starts - synced, no flickering
    final themePref = ref.watch(sharedPreferencesProvider);
    final savedTheme = themePref.getString(StorageKeys.themeMode);
    return _decode(savedTheme);
  }

  /// Method to save the user selected theme in the shared preferences
  Future<void> setThemeMode(ThemeMode mode) async {
    // 1. Update the UI immediately (optimistic approach) — so the user doesn't even notice the delay.
    state = mode;

    final themePref = ref.read(sharedPreferencesProvider);
    await themePref.setString(StorageKeys.themeMode, _encode(mode));
  }

  /// Quick toggle — Light <-> Dark (skips system setting).
  /// Useful when a simple toggle icon is needed in the app bar.
  Future<void> toggle(BuildContext context) async {
    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    final isCurrentlyDark = switch (state) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system => platformBrightness == Brightness.dark,
    };
    await setThemeMode(isCurrentlyDark ? ThemeMode.light : ThemeMode.dark);
  }

  String _encode(ThemeMode mode) => mode.name;

  ThemeMode _decode(String? value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
    // null (app opened for the first time) or a corrupted value —
    // the system default is the safest fallback
      _ => ThemeMode.system,
    };
  }


}