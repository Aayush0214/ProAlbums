import 'dart:typed_data';

/// A subtitle file the person picked: its name and its text.
typedef SubtitleFile = ({String name, String text});

/// The video player's tools that need the phone.
abstract interface class VideoToolsRepository {
  /// Saves the frame at [position] of video [id] to Pictures/Screenshots
  /// ("Videoshot_YYYYMMDD_HHMMSS.jpg"). A small preview of it, or null when
  /// it could not be saved.
  Future<Uint8List?> captureFrame(String id, Duration position);

  /// The screen brightness 0..1 for this app's window.
  Future<double> brightness();

  /// Sets this window's brightness (0..1); null = the phone's own again.
  Future<void> setBrightness(double? value);

  /// The media volume 0..1.
  Future<double> volume();

  /// Sets the media volume (0..1); answers what it really became (the phone
  /// has steps).
  Future<double> setVolume(double value);

  /// The person picks a subtitle file. null = cancelled or unreadable.
  Future<SubtitleFile?> pickSubtitle();
}
