/// Lightweight date formatting.
///
/// The app deliberately avoids `intl` for now, so these helpers cover only the
/// English, en-US-shaped strings the design actually shows.
library;

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

const _monthsShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const _weekdays = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday',
  'Friday', 'Saturday', 'Sunday',
];

/// Strips the time component so two days can be compared by identity.
DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String monthName(int month) => _months[month - 1];

String monthShort(int month) => _monthsShort[month - 1];

/// "October 2026"
String monthYear(DateTime d) => '${monthName(d.month)} ${d.year}';

/// "THURSDAY, OCTOBER 1" — the Home screen eyebrow.
String fullDateLabel(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${monthName(d.month)} ${d.day}'.toUpperCase();

/// "Today", "Tomorrow", "Yesterday" or "Oct 3" — used in list row metadata.
String relativeDayLabel(DateTime date, {DateTime? now}) {
  final today = dayOf(now ?? DateTime.now());
  final target = dayOf(date);
  final diff = target.difference(today).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  if (target.year != today.year) {
    return '${monthShort(target.month)} ${target.day}, ${target.year}';
  }
  return '${monthShort(target.month)} ${target.day}';
}

/// "2:30 PM"
String timeLabel(DateTime d) {
  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${d.hour < 12 ? 'AM' : 'PM'}';
}

/// "01/10/2026" — the date field format shown in the creation sheets.
String slashDate(DateTime d) {
  final day = d.day.toString().padLeft(2, '0');
  final month = d.month.toString().padLeft(2, '0');
  return '$day/$month/${d.year}';
}

/// "09.00" — the time field format shown in the new-event sheet.
String dottedTime(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}.${d.minute.toString().padLeft(2, '0')}';

/// Two-digit counter used beside section headers: "02", "03".
String counterLabel(int value) => value.toString().padLeft(2, '0');

/// "Good morning" / "Good afternoon" / "Good evening".
String greetingFor(DateTime now) {
  if (now.hour < 12) return 'Good morning';
  if (now.hour < 18) return 'Good afternoon';
  return 'Good evening';
}
