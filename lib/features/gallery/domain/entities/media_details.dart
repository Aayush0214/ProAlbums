/// Everything the "Info" card shows about one photo / video. Pure Dart: the
/// data layer fills it from the file and its EXIF (camera) data.
final class MediaDetails {
  const MediaDetails({
    required this.name,
    required this.path,
    required this.width,
    required this.height,
    this.sizeBytes,
    this.camera,
    this.focalLength35mm,
    this.aperture,
    this.shutterSeconds,
    this.iso,
    this.exposureBias,
    this.flashFired,
  });

  /// File name without the ending ("IMG_20261012_131652").
  final String name;

  /// Where it is, as the person knows it ("Phone storage/DCIM/Camera/...").
  final String path;

  final int width;
  final int height;

  final int? sizeBytes;

  /// "iQOO Z9 5G, iQOO" (model, make). null when the file has no camera data.
  final String? camera;

  final double? focalLength35mm;
  final double? aperture;
  final double? shutterSeconds;
  final int? iso;
  final double? exposureBias;

  /// Did the flash fire? null when the file does not say.
  final bool? flashFired;

  /// At least one shooting detail exists (then the card shows the camera part).
  bool get hasShootingData =>
      focalLength35mm != null ||
      aperture != null ||
      shutterSeconds != null ||
      iso != null ||
      exposureBias != null;
}
