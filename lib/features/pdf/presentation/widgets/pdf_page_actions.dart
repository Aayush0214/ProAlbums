import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/app/router/app_routes.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/actions/media_actions.dart';
import 'package:proalbums/features/gallery/presentation/images/media_thumbnail_image.dart';
import 'package:proalbums/features/gallery/presentation/viewer/providers/viewer_providers.dart';
import 'package:proalbums/features/gallery/presentation/viewer/providers/viewer_session_provider.dart';
import 'package:proalbums/features/pdf/domain/entities/pdf_document.dart';
import 'package:proalbums/features/pdf/presentation/providers/pdf_providers.dart';
import 'package:proalbums/shared/widgets/app_snack_bar.dart';

/// "+" (Convert PDF and Adjust image): pictures from "Select items", added
/// after the other pages. Never more than [PdfRules.maxPages] in all.
Future<void> addPdfPictures(BuildContext context, WidgetRef ref) async {
  final remaining = PdfRules.maxPages - ref.read(pdfPagesProvider).length;
  if (remaining <= 0) {
    AppToast.of(context)
        .show('A PDF can have at most ${PdfRules.maxPages} pictures');
    return;
  }
  final picked = await context.push<List<MediaItem>>(
    AppRoutes.pickItemsWith(max: remaining, imagesOnly: true),
  );
  if (picked == null || picked.isEmpty || !context.mounted) return;
  ref.read(pdfPagesProvider.notifier).add(picked);
}

/// A page in the look-only viewer (swipe through all pages, edited ones as
/// edited). [editable] (Adjust image) adds a "Crop & rotate" button.
void openPdfPage(
  BuildContext context,
  WidgetRef ref,
  MediaItem page, {
  bool editable = false,
}) {
  final edit = ref.read(pdfPageEditsProvider)[page.id];
  ref
      .read(viewerSessionProvider.notifier)
      .start(
        ViewerSessionData(
          items: pdfPreviewItemsProvider,
          mediaContext: MediaContext.preview,
          imageLoader: _previewLoader(ref),
          extraActions: [
            if (editable)
              ViewerExtraAction(
                label: 'Crop & rotate',
                icon: LucideIcons.crop,
                onPressed: (context, shown) {
                  final original = _pageOf(ref, shown);
                  if (original != null) {
                    context.push<void>(AppRoutes.pdfEditPage(original.id));
                  }
                },
              ),
          ],
        ),
      );
  final id = edit == null ? page.id : '$pdfEditedIdPrefix${edit.path}';
  context.push<void>(AppRoutes.viewer(id));
}

/// The page behind an item of the preview viewer (edited pages have
/// another id there).
MediaItem? _pageOf(WidgetRef ref, MediaItem shown) {
  final pages = ref.read(pdfPagesProvider);
  final previews = ref.read(pdfPreviewItemsProvider);
  final index = previews.indexWhere((item) => item.id == shown.id);
  return index < 0 || index >= pages.length ? null : pages[index];
}

/// The viewer's pictures: an edited page's own file, else the gallery
/// picture at the asked size.
ThumbnailLoader _previewLoader(WidgetRef ref) {
  final images = ref.read(mediaImageRepositoryProvider);
  return (id, size) async {
    if (id.startsWith(pdfEditedIdPrefix)) {
      final file = File(id.substring(pdfEditedIdPrefix.length));
      return file.existsSync() ? file.readAsBytes() : null;
    }
    final result = await images.loadDisplayImage(id: id, maxLongEdge: size);
    return result.getOrElse((_) => null);
  };
}
