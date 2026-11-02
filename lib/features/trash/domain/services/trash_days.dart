/// How long Android keeps a deleted picture.
const int kTrashDays = 30;

/// Whole days left before [expiresAt] (a started day counts: 29.2 days = 30).
/// Without a date, the full 30 days are assumed. Never below 0 or above 30.
int trashDaysLeft(DateTime? expiresAt, DateTime now) {
  if (expiresAt == null) return kTrashDays;
  final minutes = expiresAt.difference(now).inMinutes;
  if (minutes <= 0) return 0;
  final days = (minutes / (24 * 60)).ceil();
  return days > kTrashDays ? kTrashDays : days;
}

/// "29 days" / "1 day" / "0 days".
String trashDaysLabel(int days) => days == 1 ? '1 day' : '$days days';
