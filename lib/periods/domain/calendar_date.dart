/// A calendar day without a time or time-zone conversion.
final class CalendarDate implements Comparable<CalendarDate> {
  CalendarDate(int year, int month, int day)
    : value = DateTime(year, month, day) {
    if (year < 1 ||
        year > 9999 ||
        value.year != year ||
        value.month != month ||
        value.day != day) {
      throw FormatException('Ungültiges Kalenderdatum.');
    }
  }

  factory CalendarDate.fromDateTime(DateTime date) =>
      CalendarDate(date.year, date.month, date.day);

  factory CalendarDate.parse(String text) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
      throw FormatException('Erwartet wird ein Datum im Format JJJJ-MM-TT.');
    }
    final parts = text.split('-').map(int.parse).toList();
    return CalendarDate(parts[0], parts[1], parts[2]);
  }

  final DateTime value;

  String get iso =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  String get display =>
      '${value.day.toString().padLeft(2, '0')}.'
      '${value.month.toString().padLeft(2, '0')}.'
      '${value.year.toString().padLeft(4, '0')}';

  /// Calendar-day distance, unaffected by 23/25-hour daylight-saving days.
  int daysUntil(CalendarDate other) => DateTime.utc(
    other.value.year,
    other.value.month,
    other.value.day,
  ).difference(DateTime.utc(value.year, value.month, value.day)).inDays;

  CalendarDate addDays(int days) {
    final date = DateTime.utc(value.year, value.month, value.day + days);
    return CalendarDate(date.year, date.month, date.day);
  }

  @override
  int compareTo(CalendarDate other) => iso.compareTo(other.iso);

  @override
  bool operator ==(Object other) => other is CalendarDate && iso == other.iso;

  @override
  int get hashCode => iso.hashCode;
}
