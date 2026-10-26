import 'package:flutter_test/flutter_test.dart';
import 'package:kuyena_tracker/periods/domain/calendar_date.dart';
import 'package:kuyena_tracker/periods/domain/period.dart';

void main() {
  test('Eine Periode kann ohne bekanntes Ende dokumentiert werden', () {
    final period = Period(id: 'periode-1', start: CalendarDate(2026, 10, 3));

    expect(period.end, isNull);
  });

  test('Beginn und Ende dürfen auf denselben Tag fallen', () {
    final date = CalendarDate(2026, 10, 3);
    final period = Period(id: 'periode-1', start: date, end: date);

    expect(period.end, period.start);
  });

  test('Ein Ende vor dem Beginn wird abgelehnt', () {
    expect(
      () => Period(
        id: 'periode-1',
        start: CalendarDate(2026, 10, 3),
        end: CalendarDate(2026, 10, 2),
      ),
      throwsArgumentError,
    );
  });

  test('Eine leere Kennung ist nicht zulässig', () {
    for (final id in ['', '   ']) {
      expect(
        () => Period(id: id, start: CalendarDate(2026, 10, 3)),
        throwsArgumentError,
      );
    }
  });

  test(
    'Eine Korrektur behält die Kennung und verändert das Original nicht',
    () {
      final original = Period(
        id: 'periode-1',
        start: CalendarDate(2026, 10, 3),
        end: CalendarDate(2026, 10, 7),
      );

      final corrected = original.correctDates(
        start: CalendarDate(2026, 10, 2),
        end: original.end,
      );

      expect(corrected.id, original.id);
      expect(corrected.start, CalendarDate(2026, 10, 2));
      expect(corrected.end, CalendarDate(2026, 10, 7));
      expect(original.start, CalendarDate(2026, 10, 3));
      expect(original.end, CalendarDate(2026, 10, 7));
    },
  );

  test('Ein Ende kann ergänzt und wieder als unbekannt angegeben werden', () {
    final original = Period(id: 'periode-1', start: CalendarDate(2026, 10, 3));
    final withEnd = original.correctDates(
      start: original.start,
      end: CalendarDate(2026, 10, 7),
    );
    final withoutEnd = withEnd.correctDates(start: withEnd.start, end: null);

    expect(withEnd.id, original.id);
    expect(withEnd.end, CalendarDate(2026, 10, 7));
    expect(withoutEnd.id, original.id);
    expect(withoutEnd.end, isNull);
    expect(withEnd.end, CalendarDate(2026, 10, 7));
  });

  test('Auch eine ungültige Korrektur wird ohne Änderung abgelehnt', () {
    final period = Period(
      id: 'periode-1',
      start: CalendarDate(2026, 10, 3),
      end: CalendarDate(2026, 10, 7),
    );

    expect(
      () => period.correctDates(
        start: CalendarDate(2026, 10, 8),
        end: period.end,
      ),
      throwsArgumentError,
    );
    expect(period.id, 'periode-1');
    expect(period.start, CalendarDate(2026, 10, 3));
    expect(period.end, CalendarDate(2026, 10, 7));
  });
}
