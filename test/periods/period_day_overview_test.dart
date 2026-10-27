import 'package:flutter_test/flutter_test.dart';
import 'package:kuyena_tracker/periods/domain/calendar_date.dart';
import 'package:kuyena_tracker/periods/domain/period.dart';
import 'package:kuyena_tracker/periods/domain/period_day_overview.dart';

void main() {
  test('Ohne passenden Beginn gibt es keinen erfundenen Tageswert', () {
    final date = CalendarDate(2026, 10, 22);
    final future = Period(id: 'a', start: CalendarDate(2026, 10, 23));
    for (final periods in [
      <Period>[],
      [future],
    ]) {
      final view = PeriodDayOverview.fromPeriods(periods, date);
      expect(view.kind, PeriodDayKind.noEntry);
      expect(view.dayNumber, isNull);
      expect(view.progress, isNull);
    }
  });

  test(
    'Der Beginn zählt als Tag 1, unbekanntes Ende liefert keinen Fortschrittsanteil',
    () {
      final period = Period(id: 'a', start: CalendarDate(2026, 10, 20));
      final first = PeriodDayOverview.fromPeriods([period], period.start);
      final third = PeriodDayOverview.fromPeriods([
        period,
      ], CalendarDate(2026, 10, 22));
      expect(first.dayNumber, 1);
      expect(third.dayNumber, 3);
      expect(third.kind, PeriodDayKind.unknownEnd);
      expect(third.progress, isNull);
    },
  );

  test(
    'Ein dokumentiertes Ende begrenzt den Periodenzeitraum einschließlich Endtag',
    () {
      final period = Period(
        id: 'a',
        start: CalendarDate(2026, 10, 20),
        end: CalendarDate(2026, 10, 24),
      );
      final middle = PeriodDayOverview.fromPeriods([
        period,
      ], CalendarDate(2026, 10, 22));
      final last = PeriodDayOverview.fromPeriods([period], period.end!);
      final after = PeriodDayOverview.fromPeriods([
        period,
      ], CalendarDate(2026, 10, 25));
      expect(middle.kind, PeriodDayKind.documentedPeriod);
      expect((middle.dayNumber, middle.documentedDuration), (3, 5));
      expect(middle.progress, closeTo(0.5, 0.0001));
      expect(
        (last.kind, last.dayNumber, last.progress),
        (PeriodDayKind.documentedPeriod, 5, 1.0),
      );
      expect((after.kind, after.dayNumber), (PeriodDayKind.afterPeriod, 6));
    },
  );

  test(
    'Eine eintägige dokumentierte Periode beginnt mit Tag 1 am Startpunkt',
    () {
      final date = CalendarDate(2026, 10, 22);
      final view = PeriodDayOverview.fromPeriods([
        Period(id: 'a', start: date, end: date),
      ], date);
      expect(
        (view.dayNumber, view.documentedDuration, view.progress),
        (1, 1, 0.0),
      );
    },
  );

  test(
    'Der jüngste passende Beginn zählt; Reihenfolge und zukünftige Einträge ändern ihn nicht',
    () {
      final older = Period(id: 'a', start: CalendarDate(2026, 9, 20));
      final latest = Period(id: 'b', start: CalendarDate(2026, 10, 20));
      final future = Period(id: 'c', start: CalendarDate(2026, 11, 20));
      final periods = [older, future, latest];
      final view = PeriodDayOverview.fromPeriods(
        periods,
        CalendarDate(2026, 10, 22),
      );
      expect(view.period!.id, 'b');
      expect(view.dayNumber, 3);
      expect(periods, [older, future, latest]);
    },
  );

  test('Überlappende dokumentierte Zeiträume werden zum Prüfen angezeigt', () {
    final periods = [
      Period(
        id: 'a',
        start: CalendarDate(2026, 10, 20),
        end: CalendarDate(2026, 10, 24),
      ),
      Period(id: 'b', start: CalendarDate(2026, 10, 22)),
    ];
    final view = PeriodDayOverview.fromPeriods(
      periods,
      CalendarDate(2026, 10, 23),
    );
    expect(view.kind, PeriodDayKind.overlapping);
    expect(view.progress, isNull);
  });

  test(
    'Kalendertage zählen über Zeitumstellung, Jahreswechsel und Schalttag korrekt',
    () {
      for (final (start, date, expected) in [
        (CalendarDate(2026, 3, 28), CalendarDate(2026, 3, 30), 3),
        (CalendarDate(2026, 10, 24), CalendarDate(2026, 10, 26), 3),
        (CalendarDate(2026, 12, 31), CalendarDate(2027, 1, 1), 2),
        (CalendarDate(2024, 2, 28), CalendarDate(2024, 3, 1), 3),
      ]) {
        final view = PeriodDayOverview.fromPeriods([
          Period(id: 'a', start: start),
        ], date);
        expect(view.dayNumber, expected);
        expect(start.daysUntil(date), expected - 1);
        expect(date.daysUntil(start), 1 - expected);
      }
    },
  );
}
