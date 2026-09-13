import '../data/models.dart';

/// Calendar operations use Bangkok wall-clock values, represented in UTC to
/// avoid the phone's local timezone affecting selected dates and minutes.
abstract final class BookingTime {
  static const morningStart = 8 * 60;
  static const morningEnd = 12 * 60;
  static const afternoonStart = 13 * 60;
  static const afternoonEnd = 16 * 60;
  static const openingMinutes = 7 * 60;
  static const _offset = Duration(hours: 7);

  static DateTime bangkokNow([DateTime? instant]) =>
      (instant ?? DateTime.now()).toUtc().add(_offset);

  static DateTime now() => bangkokNow();

  static DateTime fromDateKey(String date) => parseDate(date);

  static DateTime today([DateTime? instant]) {
    final now = bangkokNow(instant);
    return DateTime.utc(now.year, now.month, now.day);
  }

  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static DateTime parseDate(String date) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
      throw const FormatException('Use a YYYY-MM-DD date.');
    }
    final value = DateTime.parse('${date}T00:00:00Z');
    if (dateKey(value) != date) {
      throw const FormatException('Choose a valid calendar date.');
    }
    return value;
  }

  static DateTime instant(String date, int minute) =>
      parseDate(date).add(Duration(minutes: minute)).subtract(_offset);

  static bool isWeekday(DateTime date) => date.weekday <= DateTime.friday;

  static DateTime nextBookableDate([DateTime? at]) {
    final now = bangkokNow(at);
    var day = today(at);
    if (now.hour * 60 + now.minute >= afternoonEnd) {
      day = day.add(const Duration(days: 1));
    }
    while (!isWeekday(day)) {
      day = day.add(const Duration(days: 1));
    }
    return day;
  }

  static String formatMinute(int minute) {
    final hour = minute ~/ 60;
    final suffix = hour >= 12 ? 'PM' : 'AM';
    return '${hour % 12 == 0 ? 12 : hour % 12}:'
        '${(minute % 60).toString().padLeft(2, '0')} $suffix';
  }

  static String formatRange(int start, int end) =>
      '${formatMinute(start)} – ${formatMinute(end)}';

  static String formatDate(String date, {bool short = false}) {
    final day = parseDate(date);
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final month = months[day.month - 1];
    return short
        ? '${day.day} ${month.substring(0, 3)}'
        : '${weekdays[day.weekday - 1]}, ${day.day} $month ${day.year}';
  }

  static String durationLabel(int minutes) {
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    if (hours == 0) return '$remainder min';
    return remainder == 0 ? '$hours hr' : '$hours hr $remainder min';
  }

  static bool overlaps(int start, int end, BusyInterval busy) =>
      start < busy.endMinute && end > busy.startMinute;

  /// Returns a user-facing issue or null. Cloud Functions remain authoritative.
  static String? validate({
    required String date,
    required int startMinute,
    required int endMinute,
    List<BusyInterval> busy = const [],
    DateTime? now,
  }) {
    DateTime day;
    try {
      day = parseDate(date);
    } on FormatException {
      return 'Choose a valid date.';
    }
    if (!isWeekday(day)) return 'Rooms are open Monday to Friday.';
    if (endMinute <= startMinute) return 'End time must be after start time.';
    final morning = startMinute >= morningStart && endMinute <= morningEnd;
    final afternoon =
        startMinute >= afternoonStart && endMinute <= afternoonEnd;
    if (!morning && !afternoon) {
      return 'Choose a time within 8:00 AM–12:00 PM or 1:00–4:00 PM.';
    }
    if (!instant(date, startMinute).isAfter((now ?? DateTime.now()).toUtc())) {
      return 'Choose a start time in the future.';
    }
    if (busy.any((value) => overlaps(startMinute, endMinute, value))) {
      return 'This time is already reserved. Please choose another time.';
    }
    return null;
  }

  static bool hasStarted(Reservation reservation, [DateTime? now]) => !instant(
    reservation.date,
    reservation.startMinute,
  ).isAfter((now ?? DateTime.now()).toUtc());

  static bool hasEnded(Reservation reservation, [DateTime? now]) => !instant(
    reservation.date,
    reservation.endMinute,
  ).isAfter((now ?? DateTime.now()).toUtc());
}
