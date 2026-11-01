import 'package:flutter_test/flutter_test.dart';
import 'package:kuyena_tracker/periods/domain/calendar_date.dart';
import 'package:kuyena_tracker/periods/domain/cycle_phase_overview.dart';
import 'package:kuyena_tracker/periods/domain/period.dart';
import 'package:kuyena_tracker/periods/domain/period_day_overview.dart';

CalendarDate date(String iso) => CalendarDate.parse(iso);
Period period(String start, [String? end, bool ongoing = false]) => Period(
  id: start,
  start: date(start),
  end: end == null ? null : date(end),
  isOngoing: ongoing,
);

final history = [
  period('2026-08-01', '2026-08-05'),
  period('2026-08-29', '2026-09-02'),
  period('2026-09-26', '2026-09-30'),
];

CyclePhaseOverview phase(
  String iso, {
  List<Period>? periods,
  bool absent = false,
  String asOf = '2026-10-29',
}) => CyclePhaseOverview.fromDay(
  PeriodDayOverview.fromPeriods(
    periods ?? history,
    date(iso),
    asOf: date(asOf),
    bleedingAbsent: absent,
  ),
);

void main() {
  test('recorded bleeding takes priority and needs no cycle history', () {
    final result = phase(
      '2026-10-29',
      periods: [period('2026-10-28', null, true)],
    );
    expect(result.phase, CyclePhase.menstruation);
    expect(result.isEstimated, isFalse);
    expect(phase('2026-09-30').phase, CyclePhase.menstruation);
  });

  test('no start stays unknown; a known range permits a provisional phase', () {
    expect(
      phase('2026-10-01', periods: []).unknownReason,
      PhaseUnknownReason.noPeriod,
    );
    expect(
      phase('2026-10-01', periods: history.skip(2).toList()).phase,
      CyclePhase.follicular,
    );
  });

  test('phase transitions use the personal mean and broad bounds', () {
    // Mean 28 days -> next start 24 October, broad range 8–14 October.
    expect(phase('2026-10-01').phase, CyclePhase.follicular);
    expect(phase('2026-10-07').phase, CyclePhase.follicular);
    expect(phase('2026-10-08').phase, CyclePhase.aroundOvulation);
    expect(phase('2026-10-14').phase, CyclePhase.aroundOvulation);
    final luteal = phase('2026-10-15');
    expect(luteal.phase, CyclePhase.luteal);
    expect(luteal.isEstimated, isTrue);
    expect(luteal.earliestOvulation, date('2026-10-08'));
    expect(luteal.latestOvulation, date('2026-10-14'));
    expect(phase('2026-10-23').phase, CyclePhase.luteal);
  });

  test('a personal 30-day interval shifts the phase range', () {
    final longer = [
      period('2026-07-01', '2026-07-05'),
      period('2026-07-31', '2026-08-04'),
      period('2026-08-30', '2026-09-03'),
    ];
    expect(phase('2026-09-12', periods: longer).phase, CyclePhase.follicular);
    final around = phase('2026-09-13', periods: longer);
    expect(around.phase, CyclePhase.aroundOvulation);
    expect(around.earliestOvulation, date('2026-09-13'));
    expect(around.latestOvulation, date('2026-09-19'));
    expect(phase('2026-09-20', periods: longer).phase, CyclePhase.luteal);
  });

  test('reached predictions never start a new cycle or retain luteal', () {
    for (final day in ['2026-10-24', '2026-10-29', '2026-12-10']) {
      final result = phase(day);
      expect(result.phase, CyclePhase.unknown);
      expect(result.unknownReason, PhaseUnknownReason.predictionReached);
    }
  });

  test('an unknown end is not a confirmed period or a later phase', () {
    final periods = [...history.take(2), period('2026-09-26')];
    expect(
      phase('2026-10-01', periods: periods).unknownReason,
      PhaseUnknownReason.unknownEnd,
    );
  });

  test('None overrides a recorded bleeding day', () {
    final result = phase('2026-09-30', absent: true);
    expect(result.phase, CyclePhase.follicular);
    expect(result.isEstimated, isTrue);
  });

  test('overlapping periods require review instead of a confident phase', () {
    final result = phase(
      '2026-10-06',
      periods: [
        period('2026-09-26', '2026-10-09'),
        period('2026-10-05', '2026-10-07'),
      ],
    );
    expect(result.unknownReason, PhaseUnknownReason.conflictingPeriods);
    expect(result.isEstimated, isFalse);
  });

  test('later starts do not change an earlier day or current estimate', () {
    final later = [...history, period('2026-10-25', '2026-10-28')];
    expect(
      phase('2026-10-07', periods: later).earliestOvulation,
      date('2026-10-08'),
    );
    expect(
      phase('2026-10-26', periods: later, asOf: '2026-10-07').phase,
      CyclePhase.unknown,
    );
  });

  test('short or conflicting spans do not force the prototype scheme', () {
    final result = phase(
      '2026-10-24',
      periods: [
        period('2026-10-01', '2026-10-03'),
        period('2026-10-11', '2026-10-13'),
        period('2026-10-21', '2026-10-23'),
      ],
    );
    expect(result.unknownReason, PhaseUnknownReason.incompatibleDates);
  });

  test('civil date limits return unknown without an exception', () {
    final result = phase(
      '0001-01-03',
      asOf: '0001-01-03',
      absent: true,
      periods: [
        period('0001-01-01', '0001-01-01'),
        period('0001-01-02', '0001-01-02'),
        period('0001-01-03', '0001-01-03'),
      ],
    );
    expect(result.unknownReason, PhaseUnknownReason.dateOutOfRange);
  });
}
