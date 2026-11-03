import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:proalbums/core/error/failures.dart';
import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/pdf/data/a4_pdf_builder.dart';
import 'package:proalbums/features/pdf/data/page_edit_applier.dart';
import 'package:proalbums/features/pdf/domain/entities/pdf_document.dart';
import 'package:proalbums/features/pdf/domain/repositories/pdf_repository.dart';
import 'package:proalbums/features/pdf/domain/usecases/pdf_usecases.dart';
import 'package:proalbums/features/pdf/presentation/providers/pdf_providers.dart';

MediaItem _item(String id, {bool video = false}) => MediaItem(
  id: id,
  type: video ? MediaType.video : MediaType.image,
  createdAt: DateTime(2026, 11, 3),
  width: 100,
  height: 100,
);

final class _FakeRepository implements PdfRepository {
  bool folderOpens = true;
  bool pdfOpens = true;
  final List<String> calls = [];

  @override
  FutureResult<String> buildPdf({
    required List<String> imageIds,
    required String fileName,
    Map<String, String> editedFiles = const {},
    PdfProgress? onProgress,
  }) async {
    calls.add('build ${imageIds.join(',')} $fileName $editedFiles');
    return right('/tmp/$fileName.pdf');
  }

  @override
  FutureResult<SavedPdf> savePdf({
    required String filePath,
    required String name,
  }) async {
    calls.add('save $filePath $name');
    return right(SavedPdf(uri: 'content://x/1', fileName: '$name.pdf'));
  }

  @override
  FutureResult<Uint8List> loadPage(String id, {String? editedPath}) async =>
      right(Uint8List(0));

  @override
  FutureResult<PdfPageEdit> savePageEdit({
    required String id,
    required Uint8List source,
    required PdfPageEditSpec spec,
  }) async => right(const PdfPageEdit(path: 'p', width: 1, height: 1));

  @override
  Future<void> clearPageEdits() async {}

  @override
  FutureResult<bool> printPictures({
    required List<String> imageIds,
    required String jobName,
    PdfProgress? onProgress,
    void Function()? onReady,
  }) async {
    calls.add('print ${imageIds.join(',')} $jobName');
    onReady?.call();
    return right(true);
  }

  @override
  FutureResult<Unit> sharePdf(String filePath) async => right(unit);

  @override
  FutureResult<bool> openFolder() async {
    calls.add('folder');
    return right(folderOpens);
  }

  @override
  FutureResult<bool> openPdf(String uri) async {
    calls.add('pdf $uri');
    return right(pdfOpens);
  }
}

void main() {
  group('PdfRules', () {
    test('suggested name: PDF ProAlbums_YYYYMMDD_HHMMSS', () {
      expect(
        PdfRules.defaultName(DateTime(2026, 11, 3, 13, 16, 37)),
        'PDF ProAlbums_20261103_131637',
      );
    });

    test('typed names are cleaned', () {
      expect(PdfRules.cleanName('  Notes  '), 'Notes');
      expect(PdfRules.cleanName('Notes.PDF'), 'Notes');
      expect(PdfRules.cleanName('a/b:c'), 'a_b_c');
      expect(PdfRules.cleanName('   '), isNull);
      expect(PdfRules.cleanName('.pdf'), isNull);
    });
  });

  group('PdfPages', () {
    late ProviderContainer container;
    PdfPages notifier() => container.read(pdfPagesProvider.notifier);
    List<String> ids() => [
      for (final i in container.read(pdfPagesProvider)) i.id,
    ];

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('start keeps the selection order, drops videos, caps at 99', () {
      notifier().start([_item('b'), _item('v', video: true), _item('a')]);
      expect(ids(), ['b', 'a']);
      notifier().start([for (var i = 0; i < 120; i++) _item('$i')]);
      expect(ids().length, PdfRules.maxPages);
    });

    test('add appends new pictures only, up to the limit', () {
      notifier().start([_item('a')]);
      expect(notifier().add([_item('a'), _item('b'), _item('c')]), 2);
      expect(ids(), ['a', 'b', 'c']);
      notifier().start([for (var i = 0; i < 98; i++) _item('$i')]);
      expect(notifier().add([_item('x'), _item('y')]), 1);
      expect(ids().last, 'x');
    });

    test('remove takes pages out, keeps the order of the rest', () {
      notifier().start([_item('a'), _item('b'), _item('c'), _item('d')]);
      notifier().remove({'b', 'd'});
      expect(ids(), ['a', 'c']);
      notifier().remove({});
      expect(ids(), ['a', 'c']);
    });

    test('move puts a page at its new place', () {
      notifier().start([_item('a'), _item('b'), _item('c')]);
      notifier().move(0, 2);
      expect(ids(), ['b', 'c', 'a']);
      notifier().move(2, 0);
      expect(ids(), ['a', 'b', 'c']);
    });
  });

  group('use cases', () {
    test('export builds then saves under the same name', () async {
      final repo = _FakeRepository();
      final result = await ExportPdfUseCase(repo)(
        pages: [_item('1'), _item('2')],
        name: 'Doc',
        editedFiles: {'2': '/e/2.jpg'},
      );
      expect(result.isRight(), isTrue);
      expect(repo.calls, [
        'build 1,2 Doc {2: /e/2.jpg}',
        'save /tmp/Doc.pdf Doc',
      ]);
    });

    test('export refuses videos and an empty list', () async {
      final repo = _FakeRepository();
      expect(
        (await ExportPdfUseCase(repo)(pages: [], name: 'x')).isLeft(),
        isTrue,
      );
      expect(
        (await ExportPdfUseCase(repo)(
          pages: [_item('1', video: true)],
          name: 'x',
        )).isLeft(),
        isTrue,
      );
      expect(repo.calls, isEmpty);
    });

    test('View after saving opens the PDF, or fails when no app can', () async {
      final repo = _FakeRepository();
      const pdf = SavedPdf(uri: 'u', fileName: 'x.pdf');
      expect((await OpenSavedPdfUseCase(repo)(pdf)).isRight(), isTrue);
      repo.pdfOpens = false;
      expect((await OpenSavedPdfUseCase(repo)(pdf)).isLeft(), isTrue);
      expect(repo.calls, ['pdf u', 'pdf u']);
    });

    test(
      'View files: folder first, then the last PDF, else a failure',
      () async {
        final repo = _FakeRepository();
        final open = OpenPdfFilesUseCase(repo);
        expect((await open(lastSavedUri: 'u')).isRight(), isTrue);
        expect(repo.calls, ['folder']);

        repo
          ..calls.clear()
          ..folderOpens = false;
        expect((await open(lastSavedUri: 'u')).isRight(), isTrue);
        expect(repo.calls, ['folder', 'pdf u']);

        repo.calls.clear();
        final none = await open();
        expect(none.getLeft().toNullable(), isA<StorageFailure>());
        expect(repo.calls, ['folder']);
      },
    );
  });

  test('A4 builder: one page per picture, a real PDF', () async {
    final jpeg = Uint8List.fromList(
      img.encodeJpg(img.Image(width: 40, height: 20)),
    );
    final bytes = await buildA4PdfBytes([jpeg, jpeg]);
    final text = String.fromCharCodes(bytes);
    expect(text.startsWith('%PDF'), isTrue);
    expect(RegExp(r'/Type\s*/Page\b').allMatches(text).length, 2);
  });

  group('Crop & rotate', () {
    final jpeg = Uint8List.fromList(
      img.encodeJpg(img.Image(width: 40, height: 20)),
    );

    test('nothing done = empty spec', () {
      expect(const PdfPageEditSpec().isEmpty, isTrue);
      expect(const PdfPageEditSpec(rotateDegrees: 360).isEmpty, isTrue);
      expect(const PdfPageEditSpec(rotateDegrees: 90).isEmpty, isFalse);
      expect(const PdfPageEditSpec(flip: true).isEmpty, isFalse);
    });

    test('a quarter turn swaps width and height', () {
      final out = applyPdfPageEdit(
        jpeg,
        const PdfPageEditSpec(rotateDegrees: 90),
      );
      expect((out.width, out.height), (20, 40));
    });

    test('crop is taken after the turn, and stays inside the picture', () {
      final out = applyPdfPageEdit(
        jpeg,
        const PdfPageEditSpec(
          rotateDegrees: 90,
          crop: (left: 2, top: 5, width: 10, height: 30),
        ),
      );
      expect((out.width, out.height), (10, 30));
      final tooBig = applyPdfPageEdit(
        jpeg,
        const PdfPageEditSpec(crop: (left: 0, top: 0, width: 99, height: 99)),
      );
      expect((tooBig.width, tooBig.height), (40, 20));
    });

    test('flip mirrors left and right', () {
      final source = img.Image(width: 2, height: 1)
        ..setPixelRgb(0, 0, 255, 255, 255)
        ..setPixelRgb(1, 0, 0, 0, 0);
      final out = applyPdfPageEdit(
        Uint8List.fromList(img.encodePng(source)),
        const PdfPageEditSpec(flip: true),
      );
      final decoded = img.decodeJpg(out.jpeg)!;
      expect(decoded.getPixel(0, 0).r, lessThan(decoded.getPixel(1, 0).r));
    });

    test('the preview list gives edited pages their own id and size', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(pdfPagesProvider.notifier).start([_item('a'), _item('b')]);
      container
          .read(pdfPageEditsProvider.notifier)
          .set('b', const PdfPageEdit(path: '/e/b.jpg', width: 30, height: 60));
      final previews = container.read(pdfPreviewItemsProvider);
      expect(previews[0].id, 'a');
      expect(previews[1].id, '$pdfEditedIdPrefix/e/b.jpg');
      expect((previews[1].width, previews[1].height), (30, 60));
      expect(container.read(pdfPageEditsProvider.notifier).files, {
        'b': '/e/b.jpg',
      });
    });
  });

  group('Print', () {
    test('job name: ProAlbums_YYYYMMDD_HHMMSS', () {
      expect(
        PdfRules.printJobName(DateTime(2026, 11, 3, 9, 5, 7)),
        'ProAlbums_20261103_090507',
      );
    });

    test('prints the pictures in order, calls onReady first', () async {
      final repo = _FakeRepository();
      var ready = false;
      final result = await PrintPicturesUseCase(repo)(
        pictures: [_item('3'), _item('1')],
        now: DateTime(2026, 11, 3, 9, 5, 7),
        onReady: () => ready = true,
      );
      expect(result.getOrElse((_) => false), isTrue);
      expect(ready, isTrue);
      expect(repo.calls, ['print 3,1 ProAlbums_20261103_090507']);
    });

    test('refuses videos, nothing, and more than the limit', () async {
      final repo = _FakeRepository();
      final print = PrintPicturesUseCase(repo);
      final now = DateTime(2026);
      expect((await print(pictures: [], now: now)).isLeft(), isTrue);
      expect(
        (await print(pictures: [_item('v', video: true)], now: now)).isLeft(),
        isTrue,
      );
      expect(
        (await print(
          pictures: [
            for (var i = 0; i <= PdfRules.maxPrintPictures; i++) _item('$i'),
          ],
          now: now,
        )).isLeft(),
        isTrue,
      );
      expect(repo.calls, isEmpty);
    });

    test('pages follow the paper chosen in the print screen', () async {
      final jpeg = Uint8List.fromList(
        img.encodeJpg(img.Image(width: 40, height: 20)),
      );
      final bytes = await buildPicturesPdfBytes([
        jpeg,
      ], PdfPageFormat.letter.landscape);
      final text = String.fromCharCodes(bytes);
      // Letter landscape = 792 x 612 points.
      expect(text, contains('/MediaBox[0 0 792 612]'));
    });
  });
}
