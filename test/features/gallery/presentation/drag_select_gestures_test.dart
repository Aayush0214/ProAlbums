import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_geometry.dart';
import 'package:proalbums/features/gallery/presentation/grid/gallery_row.dart';
import 'package:proalbums/features/gallery/presentation/providers/gallery_rows_provider.dart';
import 'package:proalbums/features/gallery/presentation/providers/photos_selection_controller.dart';
import 'package:proalbums/features/gallery/presentation/widgets/drag_select_gestures.dart';

MediaItem _item(int i) => MediaItem(
      id: '$i',
      type: MediaType.image,
      createdAt: DateTime(2026, 10, 12),
      width: 1,
      height: 1,
    );

void main() {
  final items = [for (var i = 0; i < 8; i++) _item(i)];
  final rows = <GalleryRow>[
    const ToolbarRow(),
    DateHeaderRow(day: DateTime(2026, 10, 12), count: 8),
    ItemsRow(items: items.sublist(0, 4), firstIndex: 0),
    ItemsRow(items: items.sublist(4), firstIndex: 4),
  ];
  // A touch on the first photo row.
  const onFirstPhoto = Offset(
    10,
    GalleryGeometry.toolbarHeight + GalleryGeometry.headerHeight + 10,
  );

  Future<ProviderContainer> pumpGrid(WidgetTester tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final geometry = GalleryGeometry(rows: rows, width: 400, columns: 4);

    final container = ProviderContainer(
      overrides: [photosDisplayItemsProvider.overrideWithValue(items)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: DragSelectGestures(
            controller: controller,
            geometry: geometry,
            viewportHeight: 600,
            child: ListView(
              controller: controller,
              children: const [SizedBox(height: 2000)],
            ),
          ),
        ),
      ),
    );
    return container;
  }

  testWidgets('one finger held on a photo starts selection', (tester) async {
    final container = await pumpGrid(tester);

    final finger = await tester.startGesture(onFirstPhoto);
    await tester.pump(const Duration(milliseconds: 700));
    await finger.up();
    await tester.pump();

    final selection = container.read(photosSelectionControllerProvider);
    expect(selection.active, isTrue);
    expect(selection.ids, {'0'});
  });

  testWidgets('two fingers (a pinch) do NOT start selection', (tester) async {
    final container = await pumpGrid(tester);

    final first = await tester.startGesture(onFirstPhoto);
    final second = await tester.startGesture(const Offset(300, 400));
    await tester.pump(const Duration(milliseconds: 700));
    await first.up();
    await second.up();
    await tester.pump();

    expect(container.read(photosSelectionControllerProvider).active, isFalse);
  });

  testWidgets('nothing starts while a pinch is in progress (enabled: false)',
      (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final container = ProviderContainer(
      overrides: [photosDisplayItemsProvider.overrideWithValue(items)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: DragSelectGestures(
            controller: controller,
            geometry: GalleryGeometry(rows: rows, width: 400, columns: 4),
            viewportHeight: 600,
            enabled: false,
            child: ListView(
              controller: controller,
              children: const [SizedBox(height: 2000)],
            ),
          ),
        ),
      ),
    );

    final finger = await tester.startGesture(onFirstPhoto);
    await tester.pump(const Duration(milliseconds: 700));
    await finger.up();
    await tester.pump();

    expect(container.read(photosSelectionControllerProvider).active, isFalse);
  });
}
