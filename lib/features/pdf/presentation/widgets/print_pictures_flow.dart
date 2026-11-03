import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/pdf/domain/entities/pdf_document.dart';
import 'package:proalbums/features/pdf/presentation/providers/pdf_providers.dart';
import 'package:proalbums/features/pdf/presentation/widgets/pdf_dialogs.dart';
import 'package:proalbums/features/pdf/presentation/widgets/print_options_sheet.dart';
import 'package:proalbums/shared/widgets/app_snack_bar.dart';

/// Print (selection bar More, viewer More): the "Print" sheet (Merge
/// Multiple Pages, Scale To), then "Preparing to print" with how many
/// pictures and a bar while they are read, then the phone's own print
/// screen (printer, copies, paper, orientation, Save as PDF...).
/// Finding and talking to the printer is Android's job, not the app's.
///
/// Videos are left out (the menu greys Print out for them anyway).
Future<void> printPictures(
  BuildContext context,
  WidgetRef ref,
  List<MediaItem> items,
) async {
  final toast = AppToast.of(context);
  final pictures = [
    for (final item in items)
      if (!item.isVideo) item,
  ];
  if (pictures.isEmpty) return;
  if (pictures.length > PdfRules.maxPrintPictures) {
    toast.show(
      'You can print up to ${PdfRules.maxPrintPictures} pictures at a time',
    );
    return;
  }

  // Merge Multiple Pages + Scale To first (the print screen has no such
  // options for other apps).
  final print = ref.read(printPicturesUseCaseProvider);
  final aspects = await print.aspects(pictures);
  if (!context.mounted) return;
  final layout = await showPrintOptionsSheet(context, aspects: aspects);
  if (layout == null || !context.mounted) return;

  final navigator = Navigator.of(context, rootNavigator: true);
  final total = pictures.length;
  final progress = ValueNotifier<(int, int)>((0, total));
  final dialog = showPdfProgressDialog(
    context,
    progress,
    title: 'Preparing to print',
    message: total == 1
        ? '1 picture will be printed'
        : '$total pictures will be printed',
  );
  var dialogOpen = true;
  void closeDialog() {
    if (!dialogOpen) return;
    dialogOpen = false;
    navigator.pop();
  }

  final result = await print(
    pictures: pictures,
    now: DateTime.now(),
    layout: layout,
    onProgress: (done, all) => progress.value = (done, all),
    // Closed just before the print screen opens.
    onReady: closeDialog,
  );
  closeDialog();
  await dialog;
  progress.dispose();
  // Printed or cancelled: the print screen and Android's notification say
  // it all. Only a failure needs a word.
  result.match((failure) => toast.show(failure.message), (_) {});
}
