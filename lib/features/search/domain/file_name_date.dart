/// When a picture was taken, from its FILE NAME (the last way to know it,
/// after MediaStore and the EXIF; like other galleries):
///  - IMG_20210209_184207.jpg, IMG20210209184207.jpg, PXL_20210209_184207…,
///    B612_20210209_184207… → that moment;
///  - IMG-20210209-WA0012.jpg (WhatsApp) → that day at noon (+ the number
///    in seconds, so the pictures of a day keep their order);
///  - photo_1612876327000.jpg → that moment (ms since 1970).
/// null = no date in the name (or an impossible one).
DateTime? dateFromFileName(String name, {DateTime? now}) {
  final latest = (now ?? DateTime.now()).add(const Duration(days: 1));
  bool ok(DateTime d) => d.year >= 2000 && !d.isAfter(latest);

  final whatsApp = RegExp(r'(?:^|\D)(\d{4})(\d{2})(\d{2})-WA(\d{1,5})')
      .firstMatch(name);
  if (whatsApp != null) {
    final d = _date(
      whatsApp,
      1,
      hour: 12,
      extraSeconds: int.parse(whatsApp[4]!),
    );
    return d != null && ok(d) ? d : null;
  }

  final moment = RegExp(
    // Up to 3 more digits after the seconds = milliseconds.
    r'(?:^|\D)(\d{4})(\d{2})(\d{2})[_-]?(\d{2})(\d{2})(\d{2})\d{0,3}(?:\D|$)',
  ).firstMatch(name);
  if (moment != null) {
    final d = _date(
      moment,
      1,
      hour: int.parse(moment[4]!),
      minute: int.parse(moment[5]!),
      second: int.parse(moment[6]!),
    );
    if (d != null && ok(d)) return d;
  }

  final epoch = RegExp(r'(?:^|\D)(1\d{12})(?:\D|$)').firstMatch(name);
  if (epoch != null) {
    final d = DateTime.fromMillisecondsSinceEpoch(int.parse(epoch[1]!));
    if (ok(d)) return d;
  }
  return null;
}

/// The date in groups [first], [first]+1, [first]+2 (year, month, day), if
/// it is a real date and time.
DateTime? _date(
  RegExpMatch match,
  int first, {
  int hour = 0,
  int minute = 0,
  int second = 0,
  int extraSeconds = 0,
}) {
  final year = int.parse(match[first]!);
  final month = int.parse(match[first + 1]!);
  final day = int.parse(match[first + 2]!);
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  if (hour > 23 || minute > 59 || second > 59) return null;
  final d = DateTime(year, month, day, hour, minute, second + extraSeconds);
  // 31 February rolls over into March: not a real date.
  if (d.month != month && extraSeconds == 0) return null;
  return d;
}
