import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/features/collage/domain/collage_layout.dart';
import 'package:proalbums/features/collage/domain/collage_rules.dart';
import 'package:proalbums/features/collage/presentation/collage_canvas.dart';

final Uint8List _pixel = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  // Two pictures side by side on a 400 × 300 collage, no margin / padding.
  final tree = collageLayoutsFor(2)
      .firstWhere((layout) => layout is CollageSplit && layout.sideBySide);

  Widget canvas({
    required void Function(int, int) onSwap,
    void Function(int?)? onSelect,
  }) => MaterialApp(
    home: Align(
      alignment: Alignment.topLeft,
      child: CollageGridCanvas(
        tree: tree,
        look: const CollageLook(
          size: Size(400, 300),
          background: Color(0xFFFFFFFF),
          corner: 0,
          margin: 0,
          padding: 0,
        ),
        images: [MemoryImage(_pixel), MemoryImage(_pixel)],
        aspects: const [1, 1],
        pictures: const [CollagePicture(), CollagePicture()],
        selected: null,
        onSelect: onSelect ?? (_) {},
        onPicture: (_, _) {},
        onSwap: onSwap,
        onTree: (_) {},
        showHandles: true,
      ),
    ),
  );

  testWidgets('hold a picture, drag it onto the other: they swap', (
    tester,
  ) async {
    (int, int)? swapped;
    await tester.pumpWidget(canvas(onSwap: (a, b) => swapped = (a, b)));

    final finger = await tester.startGesture(const Offset(100, 150));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    // The lifted copy follows the finger to the right cell.
    for (var x = 120.0; x <= 300; x += 30) {
      await finger.moveTo(Offset(x, 150));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await finger.up();
    await tester.pumpAndSettle();

    expect(swapped, (0, 1));
  });

  testWidgets('dropped back on itself: no swap', (tester) async {
    var swaps = 0;
    await tester.pumpWidget(canvas(onSwap: (_, _) => swaps++));
    final finger = await tester.startGesture(const Offset(100, 150));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await finger.moveTo(const Offset(110, 160));
    await tester.pump();
    await finger.up();
    await tester.pumpAndSettle();
    expect(swaps, 0);
  });

  testWidgets('a single tap chooses the picture (no swap, no hold)', (
    tester,
  ) async {
    int? chosen;
    await tester.pumpWidget(
      canvas(onSwap: (_, _) {}, onSelect: (slot) => chosen = slot),
    );
    await tester.tapAt(const Offset(300, 150));
    await tester.pumpAndSettle();
    expect(chosen, 1);
  });
}
