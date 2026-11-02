import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/features/gallery/presentation/viewer/format_details.dart';

void main() {
  test('formatFileSize', () {
    expect(formatFileSize(500), '500B');
    expect(formatFileSize(532 * 1024), '532KB');
    expect(formatFileSize((1.13 * 1024 * 1024).round()), '1.13MB');
    expect(formatFileSize(3 * 1024 * 1024 * 1024), '3.00GB');
  });

  test('formatShutter', () {
    expect(formatShutter(0.01), '1/100s');
    expect(formatShutter(0.5), '1/2s');
    expect(formatShutter(2), '2s');
    expect(formatShutter(1.5), '1.5s');
    expect(formatShutter(0), '');
  });

  test('formatAperture / focal length / exposure', () {
    expect(formatAperture(1.79), 'f/1.79');
    expect(formatAperture(2), 'f/2');
    expect(formatFocalLength(26), '26.00 mm');
    expect(formatExposureBias(0), 'EV 0');
    expect(formatExposureBias(-1), 'EV -1');
    expect(formatExposureBias(0.7), 'EV 0.7');
  });
}
