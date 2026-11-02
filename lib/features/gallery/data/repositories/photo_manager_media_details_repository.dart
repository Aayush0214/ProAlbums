import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:native_exif/native_exif.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:proalbums/core/error/failures.dart';
import 'package:proalbums/core/logging/app_logger.dart';
import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/gallery/data/repositories/exif_parsing.dart';
import 'package:proalbums/features/gallery/domain/entities/media_details.dart';
import 'package:proalbums/features/gallery/domain/repositories/media_details_repository.dart';

/// Name, place and size come from photo_manager; the camera data from the
/// EXIF block of the picture, read natively by Android's own ExifInterface.
final class PhotoManagerMediaDetailsRepository implements MediaDetailsRepository {
  const PhotoManagerMediaDetailsRepository();

  @override
  FutureResult<MediaDetails?> load(String id) async {
    try {
      final asset = await AssetEntity.fromId(id);
      if (asset == null) return right<Failure, MediaDetails?>(null);

      final title = await asset.titleAsync;
      final file = await asset.originFile;
      final size = file == null ? null : await file.length();
      final exif = (asset.type == AssetType.image && file != null)
          ? await _readExif(file)
          : const <String, Object>{};

      String? text(String key) => exif[key]?.toString();

      final iso = parseExifNumber(
        text('ISOSpeedRatings') ?? text('PhotographicSensitivity'),
      );

      return right<Failure, MediaDetails?>(
        MediaDetails(
          name: _withoutEnding(title),
          path: _displayPath(asset.relativePath, title),
          width: asset.orientatedWidth,
          height: asset.orientatedHeight,
          sizeBytes: size,
          camera: cameraNameOf(
            model: text('Model'),
            make: text('Make'),
          ),
          focalLength35mm: parseExifNumber(text('FocalLengthIn35mmFilm')),
          aperture: parseExifNumber(text('FNumber')),
          shutterSeconds: parseExifNumber(text('ExposureTime')),
          iso: iso?.round(),
          exposureBias: parseExifNumber(text('ExposureBiasValue')),
          flashFired: _flashFired(text('Flash')),
        ),
      );
    } on Object catch (error, stackTrace) {
      AppLogger.e('Could not read the details', error: error, stackTrace: stackTrace);
      return left<Failure, MediaDetails?>(
        const MediaFailure('Could not read the details.'),
      );
    }
  }

  // native_exif's getAttributes() only returns a fixed list of 34 tags (no
  // 35 mm focal length, no exposure bias), but getAttribute(tag) can read ANY
  // tag. So we ask for exactly the tags the Info card needs.
  static const List<String> _tags = [
    'Model',
    'Make',
    'FNumber',
    'ExposureTime',
    'ISOSpeedRatings',
    'PhotographicSensitivity',
    'FocalLengthIn35mmFilm',
    'ExposureBiasValue',
    'Flash',
  ];

  Future<Map<String, Object>> _readExif(File file) async {
    Exif? exif;
    try {
      final opened = exif = await Exif.fromPath(file.path);
      final values = await Future.wait(_tags.map(opened.getAttribute));
      final result = <String, Object>{
        for (var i = 0; i < _tags.length; i++)
          if (values[i] != null) _tags[i]: values[i] as Object,
      };
      AppLogger.d('[exif] ${file.path} -> $result');
      return result;
    } on Object catch (error, stackTrace) {
      // No EXIF is normal (screenshots, PNG), but log it to find real faults.
      AppLogger.e('EXIF not read', error: error, stackTrace: stackTrace);
      return const <String, Object>{};
    } finally {
      await exif?.close();
    }
  }

  /// EXIF "Flash" is a number; the lowest bit means "fired".
  bool? _flashFired(String? text) {
    final value = parseExifNumber(text);
    return value == null ? null : (value.round() & 1) == 1;
  }

  String _withoutEnding(String title) {
    final dot = title.lastIndexOf('.');
    return dot > 0 ? title.substring(0, dot) : title;
  }

  String _displayPath(String? relativePath, String? title) {
    final folder = relativePath ?? '';
    final base = Platform.isAndroid ? 'Phone storage/' : '';
    return '$base$folder${title ?? ''}';
  }
}
