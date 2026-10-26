import 'package:flutter_test/flutter_test.dart';
import 'package:kuyena_tracker/periods/domain/calendar_date.dart';

void main() {
  test('Speicherformat und Anzeige sind eindeutig', () {
    final date = CalendarDate(2026, 2, 3);
    expect(date.iso, '2026-02-03');
    expect(date.display, '03.02.2026');
    expect(CalendarDate.parse(date.iso), date);
  });

  test('Kalendertag bleibt ohne Umrechnung in UTC erhalten', () {
    expect(
      CalendarDate.fromDateTime(DateTime(2026, 10, 25, 23, 59)),
      CalendarDate(2026, 10, 25),
    );
    expect(
      CalendarDate.fromDateTime(DateTime.utc(2026, 10, 25, 0, 1)),
      CalendarDate(2026, 10, 25),
    );
  });

  test('Schalttag wird nur in einem Schaltjahr akzeptiert', () {
    expect(CalendarDate.parse('2024-02-29'), CalendarDate(2024, 2, 29));
    expect(() => CalendarDate.parse('2025-02-29'), throwsFormatException);
  });

  test(
    'Ungültige Werte werden nicht automatisch in andere Tage verschoben',
    () {
      for (final text in [
        '2026-02-31',
        '2026-13-01',
        '2026-00-01',
        '2026-01-00',
        '0000-01-01',
        '2026-1-1',
        '2026-01-01T00:00:00Z',
      ]) {
        expect(
          () => CalendarDate.parse(text),
          throwsFormatException,
          reason: text,
        );
      }
    },
  );
}
