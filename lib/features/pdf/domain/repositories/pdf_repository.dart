import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/pdf/domain/entities/pdf_document.dart';

/// Called while the pictures are read: [done] of [total].
typedef PdfProgress = void Function(int done, int total);

/// Makes, saves, shares and opens PDFs of pictures.
abstract interface class PdfRepository {
  /// Makes an A4 PDF, one picture per page, in this order. Returns the path
  /// of the file (in the app's temporary folder, named [fileName] + ".pdf").
  /// A page in [editedFiles] (id -> JPEG path) uses that picture instead.
  FutureResult<String> buildPdf({
    required List<String> imageIds,
    required String fileName,
    Map<String, String> editedFiles = const {},
    PdfProgress? onProgress,
  });

  /// The picture of a page for the editor: [editedPath] when it was edited
  /// before (edits add up), else the gallery picture at PDF size.
  FutureResult<Uint8List> loadPage(String id, {String? editedPath});

  /// Applies [spec] to [source] and keeps the result as the page's new
  /// picture (a JPEG in the app's temporary folder).
  FutureResult<PdfPageEdit> savePageEdit({
    required String id,
    required Uint8List source,
    required PdfPageEditSpec spec,
  });

  /// Forgets every page edit (a new PDF starts).
  Future<void> clearPageEdits();

  /// Width / height of each picture as it is shown (turned by its EXIF
  /// orientation), in order; 1 when unknown. For the print preview.
  Future<List<double>> pictureAspects(List<String> imageIds);

  /// Print: reads the pictures (one page each, [onProgress] while reading),
  /// calls [onReady], then opens the phone's print screen named [jobName].
  /// Paper size, orientation, copies and the printer are chosen there; the
  /// pages are made again for every paper choice. true = sent to print (or
  /// saved as PDF there), false = cancelled. [layout] = Merge Multiple
  /// Pages + Scale To.
  FutureResult<bool> printPictures({
    required List<String> imageIds,
    required String jobName,
    PrintLayout layout = const PrintLayout(),
    PdfProgress? onProgress,
    void Function()? onReady,
  });

  /// Copies the file at [filePath] into [PdfRules.folder] as [name] + ".pdf".
  FutureResult<SavedPdf> savePdf({
    required String filePath,
    required String name,
  });

  /// Opens the system share sheet with the file at [filePath].
  FutureResult<Unit> sharePdf(String filePath);

  /// Opens a file manager at [PdfRules.folder]. false = no app could.
  FutureResult<bool> openFolder();

  /// Opens a saved PDF in a PDF viewer. false = no app could.
  FutureResult<bool> openPdf(String uri);
}
