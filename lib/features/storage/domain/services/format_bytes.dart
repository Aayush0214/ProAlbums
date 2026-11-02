/// 1536 -> "1.5 KB", 5 * 1024^3 -> "5.0 GB". Units are 1024 based, like the
/// phone's own storage screen shows them. Pure, so it is tested.
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  // 100 GB and more: no decimals ("237 GB"); smaller: one ("5.0 GB").
  final text = value >= 100 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  return '$text ${units[unit]}';
}

/// 0.0685 -> "6.9%", 0 -> "0%", 0.004 -> "<1%". [share] is 0..1.
String formatPercent(double share) {
  if (share <= 0) return '0%';
  if (share < 0.01) return '<1%';
  final value = share * 100;
  return value >= 10 ? '${value.round()}%' : '${value.toStringAsFixed(1)}%';
}
