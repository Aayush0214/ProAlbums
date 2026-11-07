import 'package:flutter/services.dart';
import 'package:proalbums/core/logging/app_logger.dart';
import 'package:proalbums/features/search/domain/search_rules.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The library as Search needs it (SearchChannel.kt) + recent searches.
abstract interface class SearchRepository {
  /// Every picture and video (not in the trash), newest first.
  Future<List<SearchMedia>> listMedia();

  Future<List<String>> recentSearches();

  Future<void> saveRecentSearches(List<String> recent);
}

final class DeviceSearchRepository implements SearchRepository {
  const DeviceSearchRepository();

  static const MethodChannel _channel = MethodChannel(
    'com.aayush.proalbums/search',
  );

  static const String _recentKey = 'search_recent';

  @override
  Future<List<SearchMedia>> listMedia() async {
    try {
      final rows = await _channel.invokeListMethod<Map<Object?, Object?>>(
        'listMedia',
      );
      return [
        for (final row in rows ?? const <Map<Object?, Object?>>[])
          (
            id: row['id']! as String,
            name: row['name'] as String? ?? '',
            album: row['album'] as String? ?? '',
            takenMs: (row['taken']! as num).toInt(),
            video: row['video'] as bool? ?? false,
            width: (row['w'] as num? ?? 0).toInt(),
            height: (row['h'] as num? ?? 0).toInt(),
            durationMs: (row['duration'] as num? ?? 0).toInt(),
          ),
      ];
    } on Object catch (error, stackTrace) {
      AppLogger.e('Search list failed', error: error, stackTrace: stackTrace);
      return const [];
    }
  }

  @override
  Future<List<String>> recentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_recentKey) ?? const [];
  }

  @override
  Future<void> saveRecentSearches(List<String> recent) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentKey, recent);
  }
}
