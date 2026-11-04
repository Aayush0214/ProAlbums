import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/cleanup/domain/cleanup_rules.dart';
import 'package:proalbums/features/cleanup/presentation/cleanup_groups_page.dart';
import 'package:proalbums/features/cleanup/presentation/cleanup_page.dart';
import 'package:proalbums/features/cleanup/presentation/cleanup_providers.dart';
import 'package:proalbums/features/gallery/presentation/images/media_thumbnail_image.dart';
import 'package:proalbums/features/gallery/presentation/viewer/providers/viewer_providers.dart';
import 'package:proalbums/features/gallery/presentation/viewer/viewer_math.dart';

/// A picture of a Cleanup set, big (like the system gallery): "2/137" on top,
/// swipe through every picture of this kind, "Select" to pick it (the same
/// choice as on the list) and Delete for what is picked.
class CleanupPreviewPage extends ConsumerStatefulWidget {
  const CleanupPreviewPage({required this.request, super.key});

  final CleanupPreviewRequest request;

  @override
  ConsumerState<CleanupPreviewPage> createState() => _CleanupPreviewPageState();
}

class _CleanupPreviewPageState extends ConsumerState<CleanupPreviewPage> {
  late final List<CleanupImage> _images = [
    for (final group
        in ref.read(cleanupScanProvider).groupsOf(widget.request.kind))
      ...group,
  ];
  late final PageController _pages = PageController(
    initialPage: _images
        .indexWhere((image) => image.id == widget.request.startId)
        .clamp(0, _images.isEmpty ? 0 : _images.length - 1),
  );
  late int _index = _pages.initialPage;

  ValueNotifier<Set<String>> get _selection => widget.request.selection;

  @override
  void initState() {
    super.initState();
    _selection.addListener(_changed);
  }

  @override
  void dispose() {
    _selection.removeListener(_changed);
    _pages.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  ImageProvider _imageOf(CleanupImage image, int longEdge) =>
      MediaThumbnailImage(
        id: image.id,
        size: longEdge,
        load: (id, size) async {
          final result = await ref.read(loadDisplayImageUseCaseProvider)(
            id: id,
            maxLongEdge: size,
          );
          return result.fold((failure) => null, (bytes) => bytes);
        },
      );

  Future<void> _delete() async {
    final picked = [
      for (final image in _images)
        if (_selection.value.contains(image.id)) image,
    ];
    if (picked.isEmpty) return;
    final done = await deleteCleanupImages(context, ref, picked);
    if (!done || !mounted) return;
    _selection.value = const {};
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_images.isEmpty) return const Scaffold(body: CleanupEmpty());
    final media = MediaQuery.of(context);
    final longEdge = viewerImageLongEdge(
      media.size.longestSide * media.devicePixelRatio,
    );
    final current = _images[_index];
    final picked = [
      for (final image in _images)
        if (_selection.value.contains(image.id)) image,
    ];
    final pickedBytes = picked.fold<int>(0, (s, i) => s + i.size);
    final isPicked = _selection.value.contains(current.id);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.pop(),
        ),
        title: Text('${_index + 1}/${_images.length}'),
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pages,
            itemCount: _images.length,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (context, index) => InteractiveViewer(
              maxScale: 4,
              child: Center(
                child: Image(
                  image: _imageOf(_images[index], longEdge),
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
              ),
            ),
          ),
          Positioned(
            right: 24,
            bottom: 16,
            child: Material(
              color: context.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  final ids = {..._selection.value};
                  if (!ids.remove(current.id)) ids.add(current.id);
                  _selection.value = ids;
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IgnorePointer(
                        child: Checkbox(value: isPicked, onChanged: (_) {}),
                      ),
                      Text('Select', style: context.textTheme.titleMedium),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(48, 8, 48, 12),
          child: SizedBox(
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(shape: const StadiumBorder()),
              onPressed: picked.isEmpty ? null : _delete,
              child: Text(
                picked.isEmpty
                    ? 'Delete'
                    : 'Delete (${cleanupFilesLabel(picked.length)}, '
                          '${cleanupSize(pickedBytes)})',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
