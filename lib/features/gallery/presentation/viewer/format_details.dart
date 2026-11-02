/// Text for the Info card. Pure functions (tested).
/// 1.13 MB style: "1.13MB", "532KB", "2.40GB".
String formatFileSize(int bytes) {
  const kb = 1024;
  const mb = kb * 1024;
  const gb = mb * 1024;
  if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(2)}GB';
  if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(2)}MB';
  if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(0)}KB';
  return '${bytes}B';
}

/// 0.01 -> "1/100s", 2 -> "2s", 0.5 -> "1/2s".
String formatShutter(double seconds) {
  if (seconds <= 0) return '';
  if (seconds >= 1) {
    final whole = seconds == seconds.roundToDouble();
    return '${whole ? seconds.round() : seconds.toStringAsFixed(1)}s';
  }
  return '1/${(1 / seconds).round()}s';
}

/// 1.79 -> "f/1.79".
String formatAperture(double aperture) => 'f/${_trim(aperture, 2)}';

/// 26 -> "26.00 mm".
String formatFocalLength(double millimetres) =>
    '${millimetres.toStringAsFixed(2)} mm';

/// 0 -> "EV 0", 0.7 -> "EV 0.7", -1 -> "EV -1".
String formatExposureBias(double bias) => 'EV ${_trim(bias, 1)}';

String _trim(double value, int digits) {
  final text = value.toStringAsFixed(digits);
  if (!text.contains('.')) return text;
  return text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}
