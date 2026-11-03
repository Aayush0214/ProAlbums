import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:fpdart/fpdart.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:proalbums/core/error/failures.dart';
import 'package:proalbums/core/logging/app_logger.dart';
import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/pdf/data/a4_pdf_builder.dart';
import 'package:proalbums/features/pdf/data/page_edit_applier.dart';
import 'package:proalbums/features/pdf/domain/entities/pdf_document.dart';
import 'package:proalbums/features/pdf/domain/repositories/pdf_repository.dart';
import 'package:share_plus/share_plus.dart';

/// JPEG bytes of a picture, its longer side at most [maxLongEdge] pixels.
typedef PdfImageLoader = Future<Uint8List?> Function(
  String id,
  int maxLongEdge,
);

/// Makes PDFs in Dart (package:pdf), saves / opens them through
/// DocumentChannel.kt (Android only) and shares them with share_plus.
final class DevicePdfRepository implements PdfRepository {
  const DevicePdfRepository(this._loadImage);

  final PdfImageLoader _loadImage;

  /// Longer side of each picture in the PDF: about 175 dpi on an A4 page.
  /// Sharp when printed or zoomed, and the file stays shareable (a few
  /// hundred KB per page).
  static const int imageLongEdge = 2048;

  static const MethodChannel _channel = MethodChannel(
    'com.aayush.proalbums/documents',
  );

  @override
  FutureResult<String> buildPdf({
    required List<String> imageIds,
    required String fileName,
    Map<String, String> editedFiles = const {},
    PdfProgress? onProgress,
  }) async {
    try {
      // One picture at a time (a phone cannot decode 99 photos at once).
      final jpegs = <Uint8List>[];
      for (final (index, id) in imageIds.indexed) {
        final edited = editedFiles[id];
        final bytes = edited != null
            ? await File(edited).readAsBytes()
            : await _loadImage(id, imageLongEdge);
        if (bytes != null) jpegs.add(bytes);
        onProgress?.call(index + 1, imageIds.length);
      }
      if (jpegs.isEmpty) {
        return left(const MediaFailure('Could not read the pictures.'));
      }
      // Off the UI thread: writing the file must not freeze the screen.
      final pdf = await Isolate.run(() => buildA4PdfBytes(jpegs));

      // Only the latest PDF is kept here (the saved copy is the real one).
      final folder = Directory(
        p.join((await getTemporaryDirectory()).path, 'pdf'),
      );
      if (folder.existsSync()) folder.deleteSync(recursive: true);
      folder.createSync(recursive: true);
      final file = File(p.join(folder.path, '$fileName.pdf'));
      await file.writeAsBytes(pdf, flush: true);
      return right(file.path);
    } on Object catch (error, stackTrace) {
      AppLogger.e(
        'Could not make the PDF',
        error: error,
        stackTrace: stackTrace,
      );
      return left(const StorageFailure('Could not make the PDF.'));
    }
  }

  @override
  FutureResult<Uint8List> loadPage(String id, {String? editedPath}) async {
    try {
      final bytes = editedPath != null
          ? await File(editedPath).readAsBytes()
          : await _loadImage(id, imageLongEdge);
      if (bytes == null) throw StateError('The picture is gone');
      return right(bytes);
    } on Object catch (error, stackTrace) {
      AppLogger.e(
        'Could not load a PDF page',
        error: error,
        stackTrace: stackTrace,
      );
      return left(const MediaFailure('Could not load this picture.'));
    }
  }

  @override
  FutureResult<PdfPageEdit> savePageEdit({
    required String id,
    required Uint8List source,
    required PdfPageEditSpec spec,
  }) async {
    try {
      // Decoding + encoding a 2048 px picture takes a moment: off the UI
      // thread.
      final edited = await Isolate.run(() => applyPdfPageEdit(source, spec));
      final folder = await _editsFolder();
      // A new name every time: images are cached by file name.
      final safeId = id.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_');
      final file = File(
        p.join(
          folder.path,
          '${safeId}_${DateTime.now().microsecondsSinceEpoch}.jpg',
        ),
      );
      await file.writeAsBytes(edited.jpeg, flush: true);
      return right(
        PdfPageEdit(
          path: file.path,
          width: edited.width,
          height: edited.height,
        ),
      );
    } on Object catch (error, stackTrace) {
      AppLogger.e(
        'Could not edit a PDF page',
        error: error,
        stackTrace: stackTrace,
      );
      return left(const MediaFailure('Could not edit this picture.'));
    }
  }

  @override
  Future<void> clearPageEdits() async {
    try {
      final folder = await _editsFolder();
      if (folder.existsSync()) folder.deleteSync(recursive: true);
    } on Object catch (error, stackTrace) {
      AppLogger.e(
        'Could not clear PDF page edits',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  FutureResult<bool> printPictures({
    required List<String> imageIds,
    required String jobName,
    PdfProgress? onProgress,
    void Function()? onReady,
  }) async {
    try {
      // Read once; every paper choice in the print screen only lays the same
      // pictures out again.
      final jpegs = <Uint8List>[];
      for (final (index, id) in imageIds.indexed) {
        final bytes = await _loadImage(id, imageLongEdge);
        if (bytes != null) jpegs.add(bytes);
        onProgress?.call(index + 1, imageIds.length);
      }
      if (jpegs.isEmpty) {
        return left(const MediaFailure('Could not read the pictures.'));
      }
      onReady?.call();
      // The phone's print screen (Android PrintManager): printers, copies,
      // paper, orientation... It asks for the pages again whenever the paper
      // or orientation changes.
      final printed = await Printing.layoutPdf(
        name: jobName,
        onLayout: (format) =>
            Isolate.run(() => buildPicturesPdfBytes(jpegs, format)),
      );
      return right(printed);
    } on Object catch (error, stackTrace) {
      AppLogger.e('Could not print', error: error, stackTrace: stackTrace);
      return left(const StorageFailure('Could not print the pictures.'));
    }
  }

  Future<Directory> _editsFolder() async {
    final folder = Directory(
      p.join((await getTemporaryDirectory()).path, 'pdf_edits'),
    );
    if (!folder.existsSync()) folder.createSync(recursive: true);
    return folder;
  }

  @override
  FutureResult<SavedPdf> savePdf({
    required String filePath,
    required String name,
  }) async {
    try {
      final saved = await _channel.invokeMapMethod<String, String>('savePdf', {
        'path': filePath,
        'name': name,
        'folder': PdfRules.folder,
      });
      final uri = saved?['uri'];
      if (uri == null) throw StateError('No address for the saved PDF');
      return right(SavedPdf(uri: uri, fileName: saved?['name'] ?? '$name.pdf'));
    } on Object catch (error, stackTrace) {
      AppLogger.e(
        'Could not save the PDF',
        error: error,
        stackTrace: stackTrace,
      );
      return left(const StorageFailure('Could not save the PDF.'));
    }
  }

  @override
  FutureResult<Unit> sharePdf(String filePath) async {
    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(filePath, mimeType: 'application/pdf')]),
      );
      return right(unit);
    } on Object catch (error, stackTrace) {
      AppLogger.e(
        'Could not share the PDF',
        error: error,
        stackTrace: stackTrace,
      );
      return left(const StorageFailure('Could not share the PDF.'));
    }
  }

  @override
  FutureResult<bool> openFolder() =>
      _open('openFolder', {'folder': PdfRules.folder});

  @override
  FutureResult<bool> openPdf(String uri) => _open('openPdf', {'uri': uri});

  FutureResult<bool> _open(String method, Map<String, String> arguments) async {
    try {
      final opened = await _channel.invokeMethod<bool>(method, arguments);
      return right(opened ?? false);
    } on Object catch (error, stackTrace) {
      AppLogger.e(
        'Could not open ($method)',
        error: error,
        stackTrace: stackTrace,
      );
      return left(const StorageFailure('Could not open the file.'));
    }
  }
}
