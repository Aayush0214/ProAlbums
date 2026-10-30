import 'package:intl/intl.dart';

/// Two-line label of a day header, e.g. ("October 12", "Monday").
typedef DayLabel = ({String title, String subtitle});

/// [day] must be a local date at midnight. [now] is a parameter (not
/// DateTime.now() inside) so tests can pin the date.
DayLabel formatDayLabel(DateTime day, {required DateTime now}) {
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = DateTime(now.year, now.month, now.day - 1);
  final monthAndDay = DateFormat.MMMMd().format(day);

  if (day == today) return (title: 'Today', subtitle: monthAndDay);
  if (day == yesterday) return (title: 'Yesterday', subtitle: monthAndDay);

  final title =
      day.year == now.year ? monthAndDay : DateFormat.yMMMMd().format(day);
  return (title: title, subtitle: DateFormat.EEEE().format(day));
}

/// "October 2026". Used by the month overview (smallest zoom level).
String formatMonthLabel(DateTime month) => DateFormat.yMMMM().format(month);

/// "August 28 - today". The floating label of the immersive view: the dates of
/// the oldest and the newest photo currently on screen.
String formatDateRange(
  DateTime older,
  DateTime newer, {
  required DateTime now,
}) {
  final olderDay = DateTime(older.year, older.month, older.day);
  final newerDay = DateTime(newer.year, newer.month, newer.day);

  String short(DateTime day) {
    final title = formatDayLabel(day, now: now).title;
    return switch (title) {
      'Today' => 'today',
      'Yesterday' => 'yesterday',
      _ => title,
    };
  }

  if (olderDay == newerDay) return formatDayLabel(olderDay, now: now).title;
  return '${short(olderDay)} - ${short(newerDay)}';
}
