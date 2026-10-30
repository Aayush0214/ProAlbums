import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/app/router/app_routes.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/gallery/domain/entities/photos_view_settings.dart';
import 'package:proalbums/features/gallery/presentation/providers/gallery_rows_provider.dart';
import 'package:proalbums/features/gallery/presentation/providers/photos_selection_controller.dart';
import 'package:proalbums/features/gallery/presentation/providers/photos_view_settings_controller.dart';
import 'package:proalbums/features/gallery/presentation/widgets/browsing_order_sheet.dart';
import 'package:proalbums/features/gallery/presentation/widgets/selection_checkbox.dart';

enum _PhotosMenuAction {
  zoomIn,
  zoomOut,
  browsingOrder,
  immersiveView,
  groupView,
  settings,
}

/// "Photos" + Search + Select + "more" menu. While selecting it becomes
/// "N selected" with a close button and a select-all toggle.
///
/// The menu changes with the zoom level, like the reference gallery:
///  - biggest photos: no "Zoom in"
///  - month overview (smallest): ONLY "Zoom in" and "Settings"
///  - "Immersive view" turns into "Group view" while immersive is on
class PhotosAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const PhotosAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(photosViewSettingsControllerProvider);
    final controller = ref.read(photosViewSettingsControllerProvider.notifier);
    final immersive = ref.watch(photosImmersiveActiveProvider);

    // Over photos the bar must be white, whatever the theme is.
    final foreground = immersive ? Colors.white : null;

    final selection = ref.watch(photosSelectionControllerProvider);
    if (selection.active) {
      return _selectionBar(context, ref, selection, foreground);
    }

    return AppBar(
      title: const Text('Photos'),
      titleTextStyle: immersive
          ? context.textTheme.headlineLarge?.copyWith(color: Colors.white)
          : null,
      systemOverlayStyle: immersive
          ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
          : null,
      // A soft dark fade behind the title keeps it readable on bright photos.
      flexibleSpace: immersive ? const _TopScrim() : null,
      actions: [
        IconButton(
          tooltip: 'Search',
          color: foreground,
          icon: const Icon(LucideIcons.search),
          onPressed: () => context.go(AppRoutes.search),
        ),
        IconButton(
          tooltip: 'Select',
          color: foreground,
          icon: const Icon(Icons.check_box_outlined),
          onPressed: ref.read(photosSelectionControllerProvider.notifier).start,
        ),
        PopupMenuButton<_PhotosMenuAction>(
          tooltip: 'More',
          iconColor: foreground,
          icon: const Icon(Icons.more_vert),
          itemBuilder: (context) => _menuItems(settings),
          onSelected: (action) => _onSelected(context, current: settings, controller: controller, action: action),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  AppBar _selectionBar(
    BuildContext context,
    WidgetRef ref,
    PhotosSelection selection,
    Color? foreground,
  ) {
    final controller = ref.read(photosSelectionControllerProvider.notifier);
    final ids = ref.watch(
      photosDisplayItemsProvider.select((items) => [for (final i in items) i.id]),
    );
    final allSelected = ids.isNotEmpty && selection.count == ids.length;

    final state = selection.count == 0
        ? SelectionState.none
        : (allSelected ? SelectionState.all : SelectionState.partial);

    return AppBar(
      centerTitle: true,
      leading: IconButton(
        tooltip: allSelected ? 'Deselect all' : 'Select all',
        icon: SelectionCheckbox(state: state),
        onPressed: allSelected
            ? controller.clearSelection
            : () => controller.selectAll(ids),
      ),
      title: Text(
        selection.count == 0 ? 'Select items' : '${selection.count} selected',
      ),
      titleTextStyle: context.textTheme.titleLarge?.copyWith(color: foreground),
      flexibleSpace: foreground != null ? const _TopScrim() : null,
      actions: [
        IconButton(
          tooltip: 'Cancel',
          color: foreground,
          icon: const Icon(Icons.close),
          onPressed: controller.exit,
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  List<PopupMenuEntry<_PhotosMenuAction>> _menuItems(PhotosViewSettings s) {
    return [
      if (s.canZoomIn)
        const PopupMenuItem(value: _PhotosMenuAction.zoomIn, child: Text('Zoom in')),
      if (s.canZoomOut)
        const PopupMenuItem(value: _PhotosMenuAction.zoomOut, child: Text('Zoom out')),
      if (!s.isOverview) ...[
        const PopupMenuItem(
          value: _PhotosMenuAction.browsingOrder,
          child: Text('Browsing order'),
        ),
        PopupMenuItem(
          value: s.immersive
              ? _PhotosMenuAction.groupView
              : _PhotosMenuAction.immersiveView,
          child: Text(s.immersive ? 'Group view' : 'Immersive view'),
        ),
      ],
      const PopupMenuItem(value: _PhotosMenuAction.settings, child: Text('Settings')),
    ];
  }

  void _onSelected(
    BuildContext context, {
    required PhotosViewSettings current,
    required PhotosViewSettingsController controller,
    required _PhotosMenuAction action,
  }) {
    switch (action) {
      case _PhotosMenuAction.zoomIn:
        controller.zoomIn();
      case _PhotosMenuAction.zoomOut:
        controller.zoomOut();
      case _PhotosMenuAction.browsingOrder:
        unawaited(
          showBrowsingOrderSheet(
            context,
            current: current.order,
            onSelected: controller.setOrder,
          ),
        );
      case _PhotosMenuAction.immersiveView:
        controller.setImmersive(enabled: true);
      case _PhotosMenuAction.groupView:
        controller.setImmersive(enabled: false);
      case _PhotosMenuAction.settings:
        unawaited(context.push<void>(AppRoutes.settings));
    }
  }
}

class _TopScrim extends StatelessWidget {
  const _TopScrim();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.mediaScrimTop, Colors.transparent],
        ),
      ),
    );
  }
}
