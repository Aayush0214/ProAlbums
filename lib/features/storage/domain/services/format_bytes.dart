/// 1500 -> "1.5 KB", 128 000 000 000 -> "128 GB". Units are 1000 based,
/// like Android's Settings and the phone's file manager (a "128 GB" phone
/// shows 128 GB, not 119). Pure, so it is tested.
String formatBytes(int bytes) {
  if (bytes < 1000) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1000;
  var unit = 0;
  while (value >= 1000 && unit < units.length - 1) {
    value /= 1000;
    unit++;
  }
  // 100 GB and more: no decimals ("128 GB"); smaller: one ("62.4 GB").
  final text = value >= 100
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return '$text ${units[unit]}';
}

/// 0.0685 -> "6.9%", 0 -> "0%", 0.004 -> "<1%". [share] is 0..1.
String formatPercent(double share) {
  if (share <= 0) return '0%';
  if (share < 0.01) return '<1%';
  final value = share * 100;
  return value >= 10 ? '${value.round()}%' : '${value.toStringAsFixed(1)}%';
}
