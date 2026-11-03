import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/viewer/providers/viewer_providers.dart';
import 'package:proalbums/features/pdf/data/device_pdf_repository.dart';
import 'package:proalbums/features/pdf/domain/entities/pdf_document.dart';
import 'package:proalbums/features/pdf/domain/repositories/pdf_repository.dart';
import 'package:proalbums/features/pdf/domain/usecases/pdf_usecases.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pdf_providers.g.dart';

@Riverpod(keepAlive: true)
PdfRepository pdfRepository(Ref ref) {
  final images = ref.watch(mediaImageRepositoryProvider);
  return DevicePdfRepository((id, maxLongEdge) async {
    final result = await images.loadDisplayImage(
      id: id,
      maxLongEdge: maxLongEdge,
    );
    return result.getOrElse((_) => null);
  });
}

@Riverpod(keepAlive: true)
ExportPdfUseCase exportPdfUseCase(Ref ref) =>
    ExportPdfUseCase(ref.watch(pdfRepositoryProvider));

@Riverpod(keepAlive: true)
SharePdfUseCase sharePdfUseCase(Ref ref) =>
    SharePdfUseCase(ref.watch(pdfRepositoryProvider));

@Riverpod(keepAlive: true)
OpenPdfFilesUseCase openPdfFilesUseCase(Ref ref) =>
    OpenPdfFilesUseCase(ref.watch(pdfRepositoryProvider));

@Riverpod(keepAlive: true)
OpenSavedPdfUseCase openSavedPdfUseCase(Ref ref) =>
    OpenSavedPdfUseCase(ref.watch(pdfRepositoryProvider));

@Riverpod(keepAlive: true)
LoadPdfPageUseCase loadPdfPageUseCase(Ref ref) =>
    LoadPdfPageUseCase(ref.watch(pdfRepositoryProvider));

@Riverpod(keepAlive: true)
EditPdfPageUseCase editPdfPageUseCase(Ref ref) =>
    EditPdfPageUseCase(ref.watch(pdfRepositoryProvider));

@Riverpod(keepAlive: true)
PrintPicturesUseCase printPicturesUseCase(Ref ref) =>
    PrintPicturesUseCase(ref.watch(pdfRepositoryProvider));

/// The pages of the PDF being made, in order. Also the swipe list of the
/// preview viewer (a plain list, like every viewer list).
///
/// Kept alive: the viewer opened from the page reads it too. The page fills
/// it each time it opens.
@Riverpod(keepAlive: true)
class PdfPages extends _$PdfPages {
  @override
  List<MediaItem> build() => const [];

  /// A new PDF: these pictures (videos are left out), at most
  /// [PdfRules.maxPages].
  void start(List<MediaItem> items) => state = List.unmodifiable(
    [
      for (final item in items)
        if (!item.isVideo) item,
    ].take(PdfRules.maxPages),
  );

  /// Pictures added with "+": after the others, skipping ones already in
  /// and anything past the limit. Returns how many were added.
  int add(List<MediaItem> items) {
    final known = {for (final item in state) item.id};
    final added = [
      for (final item in items)
        if (!item.isVideo && known.add(item.id)) item,
    ].take(PdfRules.maxPages - state.length).toList();
    if (added.isNotEmpty) state = List.unmodifiable([...state, ...added]);
    return added.length;
  }

  /// Drag to reorder: the page at [from] goes to [to] (an index in the list
  /// WITHOUT the moved page, like ReorderableList's after adjusting).
  void move(int from, int to) {
    if (from == to || from < 0 || from >= state.length) return;
    final next = [...state];
    final page = next.removeAt(from);
    next.insert(to.clamp(0, next.length), page);
    state = List.unmodifiable(next);
  }

  /// Adjust image > Delete: these pages leave the PDF (the pictures
  /// themselves stay in the gallery).
  void remove(Set<String> ids) {
    if (ids.isEmpty) return;
    state = List.unmodifiable([
      for (final item in state)
        if (!ids.contains(item.id)) item,
    ]);
  }
}

/// "Crop & rotate" results: page id -> its edited picture. Only the PDF
/// uses them; the gallery's pictures never change.
@Riverpod(keepAlive: true)
class PdfPageEdits extends _$PdfPageEdits {
  @override
  Map<String, PdfPageEdit> build() => const {};

  /// A new PDF: no edits (their files are deleted too).
  void clear() {
    state = const {};
    ref.read(pdfRepositoryProvider).clearPageEdits();
  }

  void set(String id, PdfPageEdit edit) =>
      state = Map.unmodifiable({...state, id: edit});

  /// id -> JPEG path, for making the PDF.
  Map<String, String> get files => {
    for (final entry in state.entries) entry.key: entry.value.path,
  };
}

/// Ids in the preview viewer start with this when the page was edited: the
/// viewer caches pictures by id, so an edited page needs its own id (with
/// the edit's file in it) to show the new picture.
const String pdfEditedIdPrefix = 'pdf-edit:';

/// What the preview viewer swipes through: the pages, edited ones with their
/// new picture's id and size.
@Riverpod(keepAlive: true)
List<MediaItem> pdfPreviewItems(Ref ref) {
  final pages = ref.watch(pdfPagesProvider);
  final edits = ref.watch(pdfPageEditsProvider);
  return [
    for (final page in pages)
      if (edits[page.id] case final edit?)
        MediaItem(
          id: '$pdfEditedIdPrefix${edit.path}',
          type: MediaType.image,
          createdAt: page.createdAt,
          width: edit.width,
          height: edit.height,
        )
      else
        page,
  ];
}
