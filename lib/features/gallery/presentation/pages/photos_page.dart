import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proalbums/features/gallery/presentation/pages/photos_body.dart';
import 'package:proalbums/features/gallery/presentation/providers/gallery_rows_provider.dart';
import 'package:proalbums/features/gallery/presentation/providers/photos_controller.dart';
import 'package:proalbums/features/gallery/presentation/providers/photos_selection_controller.dart';
import 'package:proalbums/features/gallery/presentation/widgets/photos_app_bar.dart';
import 'package:proalbums/features/gallery/presentation/widgets/selection_action_bar.dart';
import 'package:proalbums/features/permissions/presentation/providers/library_access_revision.dart';
import 'package:proalbums/features/permissions/presentation/providers/limited_access_banner_provider.dart';
import 'package:proalbums/features/permissions/presentation/providers/visible_media_providers.dart';
import 'package:proalbums/features/permissions/presentation/widgets/limited_access_banner.dart';
import 'package:proalbums/features/permissions/presentation/widgets/limited_access_empty_state.dart';
import 'package:proalbums/shared/shell/shell_bottom_bar_provider.dart';

/// The Photos tab: app bar + the grid (+ the action bar while selecting).
class PhotosPage extends ConsumerWidget {
  const PhotosPage({super.key});

  static const String _owner = 'photos-selection';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final immersive = ref.watch(photosImmersiveActiveProvider);
    final selecting = ref.watch(
      photosSelectionControllerProvider.select((s) => s.active),
    );

    // The user changed the photo access (Select more / Allow all): the
    // library is different now, so load it again.
    ref.listen(
      libraryAccessRevisionProvider,
      (previous, next) => ref.invalidate(photosControllerProvider),
    );

    // Allowed only selected photos and selected none: explain, do not show
    // a blank grid.
    final limitedEmpty = ref.watch(limitedLibraryIsEmptyProvider);
    final showBanner =
        ref.watch(showLimitedAccessBannerProvider) && !limitedEmpty;

    // While selecting, the action bar takes the place of the navigation bar.
    ref.listen(
      photosSelectionControllerProvider.select((s) => s.active),
      (previous, active) {
        final bar = ref.read(shellBottomBarHiddenProvider.notifier);
        if (active) {
          bar.hide(_owner);
        } else {
          bar.show(_owner);
        }
      },
    );

    // Back while selecting = leave selection mode (not the app).
    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) ref.read(photosSelectionControllerProvider.notifier).exit();
      },
      child: Scaffold(
        // Immersive view: the photos run BEHIND the (transparent) app bar and
        // the status bar. The bottom navigation bar stays visible.
        extendBodyBehindAppBar: immersive,
        appBar: const PhotosAppBar(),
        bottomNavigationBar: selecting ? const SelectionActionBar() : null,
        body: Column(
          children: [
            // Not in immersive view (only photos) and not while selecting.
            if (showBanner && !immersive && !selecting)
              const LimitedAccessBanner(),
            Expanded(
              child: limitedEmpty
                  ? const LimitedAccessEmptyState()
                  : PhotosBody(
                // Status bar + app bar. Measured HERE, above the Scaffold, so
                // it is exact whether the body goes behind the app bar or not.
                appBarExtent: MediaQuery.paddingOf(context).top + kToolbarHeight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
