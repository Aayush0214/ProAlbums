import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/shared/widgets/slideshow_player.dart';

/// A 1×1 transparent PNG.
final Uint8List _pixel = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  group('zoom in, out, in…', () {
    test('a picture starts at the size the one before ends at', () {
      expect(
        slideZoomAt(zoomIn: true, amount: 0.25, life: 1),
        slideZoomAt(zoomIn: false, amount: 0.25, life: 0),
      );
      expect(
        slideZoomAt(zoomIn: false, amount: 0.25, life: 1),
        slideZoomAt(zoomIn: true, amount: 0.25, life: 0),
      );
    });

    test('zooming out never gets smaller than the screen fit', () {
      expect(slideZoomAt(zoomIn: false, amount: 0.25, life: 1.6), 1);
    });
  });

  testWidgets('goes through the pictures in order, then finishes', (
    tester,
  ) async {
    final shown = <int>[];
    var finished = false;
    const options = SlideshowOptions(
      slide: Duration(milliseconds: 100),
      fade: Duration(milliseconds: 50),
    );

    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: SlideshowPlayer(
            count: 3,
            options: options,
            // A new provider per index (so precaching really loads each).
            imageAt: (index) => MemoryImage(Uint8List.fromList(_pixel)),
            onIndex: shown.add,
            onFinished: () => finished = true,
          ),
        ),
      );
      for (var i = 0; i < 20 && !finished; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 60));
        await tester.pump(const Duration(milliseconds: 60));
      }
    });

    expect(shown, [0, 1, 2]);
    expect(finished, isTrue);
  });

  testWidgets('the old picture fades OUT and leaves (nothing stays behind)', (
    tester,
  ) async {
    const options = SlideshowOptions(
      slide: Duration(milliseconds: 100),
      fade: Duration(milliseconds: 50),
    );
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: SlideshowPlayer(
            count: 2,
            options: options,
            imageAt: (index) => MemoryImage(Uint8List.fromList(_pixel)),
            onFinished: () {},
          ),
        ),
      );
      // Past the switch to picture 2 and its whole cross-fade.
      for (var i = 0; i < 8; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 60));
        await tester.pump(const Duration(milliseconds: 60));
      }
    });
    expect(find.byType(Image), findsOneWidget);
  });
}
