import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/features/gallery/presentation/viewer/histogram.dart';

void main() {
  test('counts every pixel into one bar per colour', () {
    // two pixels: pure black, pure white
    final rgba = Uint8List.fromList([0, 0, 0, 255, 255, 255, 255, 255]);
    final h = HistogramData.fromRgba(rgba);

    expect(h.red[0], 1);
    expect(h.red[kHistogramBins - 1], 1);
    expect(h.green.reduce((a, b) => a + b), 2);
    expect(h.blue.reduce((a, b) => a + b), 2);
    expect(h.peak, 1);
  });

  test('the brightness steps are grouped in fours', () {
    final rgba = Uint8List.fromList([3, 4, 8, 255]);
    final h = HistogramData.fromRgba(rgba);
    expect(h.red[0], 1); // 3 >> 2 == 0
    expect(h.green[1], 1); // 4 >> 2 == 1
    expect(h.blue[2], 1); // 8 >> 2 == 2
  });

  test('an empty picture has no peak', () {
    expect(HistogramData.fromRgba(Uint8List(0)).peak, 0);
  });
}
