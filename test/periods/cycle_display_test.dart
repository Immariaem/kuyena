import 'package:flutter_test/flutter_test.dart';
import 'package:kuyena_tracker/periods/domain/calendar_date.dart';
import 'package:kuyena_tracker/periods/domain/cycle_display.dart';
import 'package:kuyena_tracker/periods/domain/period.dart';
import 'package:kuyena_tracker/periods/domain/period_day_overview.dart';

CalendarDate d(int n) => CalendarDate(2026, 10, n);
CycleDisplay display(
  int n, {
  int? length,
  bool ongoing = false,
  bool unknown = false,
  Set<CalendarDate> holes = const {},
}) => CycleDisplay.fromDay(
  PeriodDayOverview.fromPeriods(
    [
      Period(
        id: '1',
        start: d(1),
        end: ongoing || unknown ? null : d(5),
        isOngoing: ongoing,
        excludedDays: holes,
      ),
    ],
    d(n),
    initialCycleLength: length,
  ),
);
void main() {
  test(
    'Whole expected period uses mean recorded bleeding duration across month boundary',
    () {
      final history = [
        Period(
          id: 'a',
          start: CalendarDate(2026, 9, 3),
          end: CalendarDate(2026, 9, 5),
        ),
        Period(id: 'b', start: d(1), end: d(5)),
      ];
      final c = CycleDisplay.fromDay(
        PeriodDayOverview.fromPeriods(history, d(8)),
        history: history,
      );
      expect(c.periodDuration, 4);
      expect(c.nextPeriodStart, d(29));
      expect(c.nextPeriodEnd, CalendarDate(2026, 11, 1));
      expect(c.expectedPeriodDays, {
        d(29),
        d(30),
        d(31),
        CalendarDate(2026, 11, 1),
      });
    },
  );
  test(
    'Incomplete periods do not invent observed durations; preference or labelled default is used',
    () {
      final ongoing = Period(id: 'a', start: d(1), isOngoing: true);
      final view = PeriodDayOverview.fromPeriods([ongoing], d(3));
      final c = CycleDisplay.fromDay(
        view,
        history: [ongoing],
        periodLengthPreference: 'long',
      );
      expect(c.periodDuration, 7);
      expect(c.durationBasis, contains('6–7'));
      final fallback = CycleDisplay.fromDay(view);
      expect(fallback.periodDuration, 5);
      expect(fallback.durationBasis, contains('Vorläufige Annahme'));
      final open = CycleDisplay.fromDay(
        view,
        periodLengthPreference: 'extended',
      );
      expect(open.periodEndOpen, isTrue);
      expect(open.durationBasis, contains('Ende offen'));
    },
  );
  test(
    'Fertility shading includes five days before earliest possible ovulation without confirming pregnancy odds',
    () {
      final c = display(8);
      expect(c.fertileStart, d(8));
      expect(c.fertileDays.length, 12);
      expect(c.days[7], CycleDayType.estimatedFertile);
      expect(c.days[12], CycleDayType.estimatedOvulation);
      expect(c.fertileDays.contains(d(19)), isTrue);
      expect(c.fertileDays.contains(d(20)), isFalse);
      expect(display(8, unknown: true).fertileDays, isEmpty);
    },
  );
  test(
    'Historical projection does not use later finished period durations',
    () {
      final history = [
        Period(id: 'a', start: d(1), end: d(3)),
        Period(id: 'b', start: d(25), end: d(31)),
      ];
      final c = CycleDisplay.fromDay(
        PeriodDayOverview.fromPeriods(history, d(8)),
        history: history,
        asOf: d(8),
      );
      expect(c.periodDuration, 3);
    },
  );
  test(
    'Boundary dates do not overflow when the forecast period end is outside supported years',
    () {
      final start = CalendarDate(9999, 12, 1), asOf = CalendarDate(9999, 12, 8);
      final c = CycleDisplay.fromDay(
        PeriodDayOverview.fromPeriods(
          [Period(id: 'last', start: start, end: CalendarDate(9999, 12, 5))],
          asOf,
          initialCycleLength: 30,
        ),
      );
      expect(c.nextPeriodStart, CalendarDate(9999, 12, 31));
      expect(c.nextPeriodEnd, isNull);
      expect(c.expectedPeriodDays, {CalendarDate(9999, 12, 31)});
    },
  );

  test(
    'Inclusive recorded range, holes, estimated window and full remaining cycle',
    () {
      final c = display(8, holes: {d(3)});
      expect(c.days.length, 28);
      expect(c.days.where((v) => v == CycleDayType.period).length, 4);
      expect(c.days[2], CycleDayType.rest);
      expect(c.ovulationStart, d(13));
      expect(c.ovulationEnd, d(19));
      expect(c.days[12], CycleDayType.estimatedOvulation);
      expect(c.days[18], CycleDayType.estimatedOvulation);
      expect(c.days[19], CycleDayType.rest);
      expect(c.daysToOvulation, 5);
    },
  );
  test('Personal length shifts both calendar dates and wheel segments', () {
    final c = display(8, length: 30);
    expect(c.days.length, 30);
    expect(c.ovulationStart, d(15));
    expect(c.daysToOvulation, 7);
  });
  test(
    'Ongoing bleeding beyond an estimate takes priority and hides incompatible window',
    () {
      final c = display(20, ongoing: true);
      expect(c.ovulationDays, isEmpty);
      expect(c.days.take(20), everyElement(CycleDayType.period));
    },
  );
  test('Unknown end and short cycles do not assert an ovulation window', () {
    expect(display(8, unknown: true).ovulationDays, isEmpty);
    expect(display(8, length: 12).ovulationDays, isEmpty);
  });
  test('Missing/conflicting records have no invented segmented cycle', () {
    expect(
      CycleDisplay.fromDay(PeriodDayOverview.fromPeriods([], d(8))).days,
      isEmpty,
    );
    final c = CycleDisplay.fromDay(
      PeriodDayOverview.fromPeriods([
        Period(id: '1', start: d(1), end: d(9)),
        Period(id: '2', start: d(5), end: d(10)),
      ], d(8)),
    );
    expect(c.days, isEmpty);
  });
  test('Overdue estimate does not loop into an invented next cycle', () {
    final c = display(30);
    expect(c.days.length, 28);
    expect(c.selectedIndex, isNull);
    expect(c.day.estimate!.expectedStart, d(29));
    expect(c.inOvulationWindow, isFalse);
    expect(c.beforeOvulation, isFalse);
  });
}
