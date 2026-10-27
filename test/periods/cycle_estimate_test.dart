import 'package:flutter_test/flutter_test.dart';
import 'package:kuyena_tracker/periods/domain/calendar_date.dart';
import 'package:kuyena_tracker/periods/domain/cycle_estimate.dart';
import 'package:kuyena_tracker/periods/domain/period.dart';
import 'package:kuyena_tracker/periods/domain/period_day_overview.dart';

List<Period> cycles({bool ongoing = false}) => [
  Period(
    id: '1',
    start: CalendarDate(2026, 8, 25),
    end: CalendarDate(2026, 8, 29),
  ),
  Period(
    id: '2',
    start: CalendarDate(2026, 9, 22),
    end: CalendarDate(2026, 9, 26),
  ),
  Period(
    id: '3',
    start: CalendarDate(2026, 10, 20),
    end: ongoing ? null : CalendarDate(2026, 10, 21),
    isOngoing: ongoing,
  ),
];

void main() {
  test(
    'Mindestens drei Beginne liefern zwei Abstände; keine Standardlänge',
    () {
      expect(CycleEstimate.fromPeriods([]), isNull);
      expect(CycleEstimate.fromPeriods(cycles().take(2)), isNull);
      final estimate = CycleEstimate.fromPeriods(cycles())!;
      expect((estimate.lengthInDays, estimate.cycleCount), (28, 2));
      expect(estimate.expectedStart, CalendarDate(2026, 11, 17));
    },
  );

  test('Median begrenzt den Einfluss eines einzelnen großen Abstands', () {
    var date = CalendarDate(2026, 1, 1);
    final periods = [Period(id: '0', start: date)];
    for (final (index, length) in [26, 28, 90].indexed) {
      date = date.addDays(length);
      periods.add(Period(id: '${index + 1}', start: date));
    }
    final estimate = CycleEstimate.fromPeriods(periods)!;
    expect(estimate.lengthInDays, 28);
    expect((estimate.shortestInterval, estimate.longestInterval), (26, 90));
    expect(estimate.expectedStart, date.addDays(28));
  });

  test('Nur die letzten sechs Abstände zählen', () {
    var date = CalendarDate(2025, 1, 1);
    final periods = [Period(id: '0', start: date)];
    for (final (index, length) in [90, 90, 27, 27, 27, 27, 27, 27].indexed) {
      date = date.addDays(length);
      periods.add(Period(id: '${index + 1}', start: date));
    }
    final estimate = CycleEstimate.fromPeriods(periods.reversed)!;
    expect((estimate.lengthInDays, estimate.cycleCount), (27, 6));
  });

  test(
    'Countdown und Ring wachsen ohne automatisch einen neuen Zyklus zu erfinden',
    () {
      final records = cycles();
      final view = PeriodDayOverview.fromPeriods(
        records,
        CalendarDate(2026, 10, 22),
      );
      expect(view.hasCountdown, isTrue);
      expect(view.daysToNext, 26);
      expect(view.progress, closeTo(2 / 28, 0.00001));
      final due = PeriodDayOverview.fromPeriods(
        records,
        CalendarDate(2026, 11, 17),
      );
      expect((due.daysToNext, due.progress), (0, 1.0));
      final passed = PeriodDayOverview.fromPeriods(
        records,
        CalendarDate(2026, 11, 20),
      );
      expect((passed.daysToNext, passed.progress), (-3, 1.0));
    },
  );

  test(
    'Aktiv ist nur ausdrücklich bestätigt; ein unbekanntes Ende genügt nicht',
    () {
      final active = PeriodDayOverview.fromPeriods(
        cycles(ongoing: true),
        CalendarDate(2026, 10, 22),
      );
      expect(active.kind, PeriodDayKind.ongoingPeriod);
      expect(active.isPeriod, isTrue);
      expect(active.hasCountdown, isFalse);
      expect(active.progress, closeTo(2 / 28, 0.00001));
      final future = PeriodDayOverview.fromPeriods(
        cycles(ongoing: true),
        CalendarDate(2026, 10, 27),
        asOf: CalendarDate(2026, 10, 22),
      );
      expect(future.isPeriod, isFalse);
      expect(future.hasCountdown, isTrue);
    },
  );

  test(
    'Historische Auswahl verwendet keine späteren Beginne für ihre Schätzung',
    () {
      final view = PeriodDayOverview.fromPeriods(
        cycles(),
        CalendarDate(2026, 9, 24),
      );
      expect(view.estimate, isNull);
    },
  );

  test('Überlappende Perioden werden nicht zur Schätzung verwendet', () {
    final records = cycles();
    records[0] = Period(
      id: '1',
      start: records[0].start,
      end: records[1].start,
    );
    expect(CycleEstimate.fromPeriods(records), isNull);
  });

  test(
    'Laufende Kennzeichnung ist mit Enddatum unvereinbar und bleibt beim Neudatieren erhalten',
    () {
      final period = Period(
        id: 'a',
        start: CalendarDate(2026, 10, 20),
        isOngoing: true,
      );
      expect(
        () => Period(
          id: 'a',
          start: period.start,
          end: period.start,
          isOngoing: true,
        ),
        throwsArgumentError,
      );
      expect(
        period
            .correctDates(start: CalendarDate(2026, 10, 19), end: null)
            .isOngoing,
        isTrue,
      );
      expect(
        period
            .correctDates(start: period.start, end: CalendarDate(2026, 10, 22))
            .isOngoing,
        isFalse,
      );
    },
  );
}
