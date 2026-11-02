import 'dart:typed_data';

/// How many bars the little brightness picture has.
const int kHistogramBins = 64;

/// How many pixels of each brightness (per colour) a picture has: the small
/// graph in the Info card.
final class HistogramData {
  const HistogramData({
    required this.red,
    required this.green,
    required this.blue,
  });

  /// [rgba] = 4 bytes per pixel (red, green, blue, alpha), like Flutter's
  /// `ImageByteFormat.rawRgba`.
  factory HistogramData.fromRgba(Uint8List rgba) {
    final red = List<int>.filled(kHistogramBins, 0);
    final green = List<int>.filled(kHistogramBins, 0);
    final blue = List<int>.filled(kHistogramBins, 0);
    const shift = 2; // 256 brightness steps -> 64 bars
    for (var i = 0; i + 3 < rgba.length; i += 4) {
      red[rgba[i] >> shift]++;
      green[rgba[i + 1] >> shift]++;
      blue[rgba[i + 2] >> shift]++;
    }
    return HistogramData(red: red, green: green, blue: blue);
  }

  final List<int> red;
  final List<int> green;
  final List<int> blue;

  /// The tallest bar of all three (the graph is drawn relative to it).
  int get peak {
    var peak = 0;
    for (final channel in [red, green, blue]) {
      for (final value in channel) {
        if (value > peak) peak = value;
      }
    }
    return peak;
  }
}
