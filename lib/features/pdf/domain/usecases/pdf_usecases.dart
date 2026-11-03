import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:proalbums/core/error/failures.dart';
import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/pdf/domain/entities/pdf_document.dart';
import 'package:proalbums/features/pdf/domain/repositories/pdf_repository.dart';

/// A PDF that was made and saved: where it is saved, and the file it was
/// made in (for sharing).
typedef ExportedPdf = ({SavedPdf saved, String filePath});

/// Makes the PDF of [pages] (in this order) and saves it as [name]. A page
/// in [editedFiles] (id -> JPEG path, from Crop & rotate) uses that picture.
final class ExportPdfUseCase {
  const ExportPdfUseCase(this._repository);

  final PdfRepository _repository;

  FutureResult<ExportedPdf> call({
    required List<MediaItem> pages,
    required String name,
    Map<String, String> editedFiles = const {},
    PdfProgress? onProgress,
  }) async {
    if (pages.isEmpty || pages.any((item) => item.isVideo)) {
      return left(const MediaFailure('Only pictures can be made into a PDF.'));
    }
    if (pages.length > PdfRules.maxPages) {
      return left(
        const MediaFailure(
          'A PDF can have at most ${PdfRules.maxPages} pictures.',
        ),
      );
    }
    final built = await _repository.buildPdf(
      imageIds: [for (final item in pages) item.id],
      fileName: name,
      editedFiles: editedFiles,
      onProgress: onProgress,
    );
    return built.match((failure) async => left(failure), (filePath) async {
      final saved = await _repository.savePdf(filePath: filePath, name: name);
      return saved.map((pdf) => (saved: pdf, filePath: filePath));
    });
  }
}

/// Opens the share sheet with a made PDF.
final class SharePdfUseCase {
  const SharePdfUseCase(this._repository);

  final PdfRepository _repository;

  FutureResult<Unit> call(String filePath) => _repository.sharePdf(filePath);
}

/// "View files": the file manager at the PDF folder. When no file manager
/// can open it, the last saved PDF itself is opened instead (if any).
final class OpenPdfFilesUseCase {
  const OpenPdfFilesUseCase(this._repository);

  final PdfRepository _repository;

  FutureResult<Unit> call({String? lastSavedUri}) async {
    final folder = await _repository.openFolder();
    if (folder.getOrElse((_) => false)) return right(unit);
    if (lastSavedUri != null) {
      final file = await _repository.openPdf(lastSavedUri);
      if (file.getOrElse((_) => false)) return right(unit);
    }
    return left(const StorageFailure('Could not open the file manager.'));
  }
}

/// "View" after saving: the saved PDF in the phone's PDF viewer.
final class OpenSavedPdfUseCase {
  const OpenSavedPdfUseCase(this._repository);

  final PdfRepository _repository;

  FutureResult<Unit> call(SavedPdf pdf) async {
    final opened = await _repository.openPdf(pdf.uri);
    if (opened.getOrElse((_) => false)) return right(unit);
    return left(const StorageFailure('No app can open this PDF.'));
  }
}

/// The picture "Crop & rotate" starts from: the page's last edit (edits add
/// up), else the gallery picture.
final class LoadPdfPageUseCase {
  const LoadPdfPageUseCase(this._repository);

  final PdfRepository _repository;

  FutureResult<Uint8List> call(String id, {PdfPageEdit? edit}) =>
      _repository.loadPage(id, editedPath: edit?.path);
}

/// "Crop & rotate" > Done: makes the page's new picture. (The editor skips
/// this when nothing changed, see [PdfPageEditSpec.isEmpty].)
final class EditPdfPageUseCase {
  const EditPdfPageUseCase(this._repository);

  final PdfRepository _repository;

  FutureResult<PdfPageEdit> call({
    required String id,
    required Uint8List source,
    required PdfPageEditSpec spec,
  }) => _repository.savePageEdit(id: id, source: source, spec: spec);
}

/// Print (selection or viewer): the pictures, one per page, in the phone's
/// print screen. Only pictures, at most [PdfRules.maxPrintPictures] at a
/// time. true = sent to print, false = cancelled.
final class PrintPicturesUseCase {
  const PrintPicturesUseCase(this._repository);

  final PdfRepository _repository;

  FutureResult<bool> call({
    required List<MediaItem> pictures,
    required DateTime now,
    PdfProgress? onProgress,
    void Function()? onReady,
  }) async {
    if (pictures.isEmpty || pictures.any((item) => item.isVideo)) {
      return left(const MediaFailure('Only pictures can be printed.'));
    }
    if (pictures.length > PdfRules.maxPrintPictures) {
      return left(
        const MediaFailure(
          'You can print up to ${PdfRules.maxPrintPictures} pictures at a '
          'time.',
        ),
      );
    }
    return _repository.printPictures(
      imageIds: [for (final item in pictures) item.id],
      jobName: PdfRules.printJobName(now),
      onProgress: onProgress,
      onReady: onReady,
    );
  }
}
