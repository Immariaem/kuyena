import 'package:flutter_test/flutter_test.dart';
import 'package:kuyena_tracker/periods/application/period_timeline.dart';
import 'package:kuyena_tracker/periods/domain/calendar_date.dart';
import 'package:kuyena_tracker/periods/domain/period.dart';
import 'package:kuyena_tracker/periods/domain/period_day_overview.dart';
import 'package:kuyena_tracker/journal/domain/day_entry.dart';

CalendarDate day(int d) => CalendarDate(2026, 10, d);
PeriodTimeline timeline(
  List<DayEntry> entries, {
  List<Period> periods = const [],
  int asOf = 28,
}) => PeriodTimeline.from(periods: periods, entries: entries, asOf: day(asOf));
void main() {
  test(
    'Symptoms, mood, energy, notes and None alone do not create a period',
    () {
      final t = timeline([
        DayEntry(
          date: day(25),
          symptoms: {Symptom.cramps},
          mood: Mood.low,
          energy: 30,
          note: 'Note',
        ),
        DayEntry(date: day(26), flow: FlowIntensity.none),
      ]);
      expect(t.periods, isEmpty);
    },
  );
  test(
    'First positive flow starts a period; repeated or missing days keep the start',
    () {
      final t = timeline([
        DayEntry(date: day(26), flow: FlowIntensity.light),
        DayEntry(date: day(28), flow: FlowIntensity.heavy),
      ]);
      expect(t.periods.length, 1);
      expect(t.periods.single.start, day(26));
      expect(t.periods.single.isOngoing, isTrue);
      expect(PeriodDayOverview.fromPeriods(t.periods, day(28)).dayNumber, 3);
      expect(t.logPeriodIds, {t.periods.single.id});
    },
  );
  test('None ends an ongoing period on the previous calendar day', () {
    final t = timeline([
      DayEntry(date: day(25), flow: FlowIntensity.medium),
      DayEntry(date: day(28), flow: FlowIntensity.none),
    ]);
    expect(t.periods.single.end, day(27));
    expect(t.periods.single.isOngoing, isFalse);
    final overview = PeriodDayOverview.fromPeriods(
      t.periods,
      day(28),
      bleedingAbsent: true,
    );
    expect(overview.isPeriod, isFalse);
    expect(overview.kind, PeriodDayKind.afterPeriod);
  });
  test('A later positive entry after None starts a new cycle', () {
    final t = timeline([
      DayEntry(date: day(1), flow: FlowIntensity.light),
      DayEntry(date: day(5), flow: FlowIntensity.none),
      DayEntry(date: day(27), flow: FlowIntensity.medium),
    ]);
    expect(t.periods.length, 2);
    expect(t.periods.first.start, day(27));
    expect(t.periods.last.end, day(4));
  });
  test('A known manual start anchors logs without creating a duplicate', () {
    final raw = Period(id: 'manual', start: day(24), isOngoing: true);
    final t = timeline(
      [
        DayEntry(date: day(26), flow: FlowIntensity.heavy),
        DayEntry(date: day(28), flow: FlowIntensity.none),
      ],
      periods: [raw],
    );
    expect(t.periods.single.id, 'manual');
    expect(t.periods.single.start, day(24));
    expect(t.periods.single.end, day(27));
    expect(t.logAdjustedIds, {'manual'});
    expect(raw.end, isNull);
    expect(raw.isOngoing, isTrue);
  });
  test('A confirmed completed period does not absorb a later blood entry', () {
    final t = timeline(
      [DayEntry(date: day(26), flow: FlowIntensity.light)],
      periods: [Period(id: 'manual', start: day(1), end: day(5))],
    );
    expect(t.periods.length, 2);
    expect(t.periods.first.start, day(26));
    expect(t.periods.last.end, day(5));
  });
  test('Future observations cannot start or end the current period', () {
    final t = timeline([
      DayEntry(date: day(26), flow: FlowIntensity.light),
      DayEntry(date: day(29), flow: FlowIntensity.none),
      DayEntry(date: day(30), flow: FlowIntensity.heavy),
    ]);
    expect(t.periods.single.isOngoing, isTrue);
    expect(t.periods.single.end, isNull);
  });
  test(
    'Correction and deletion derive a fresh timeline without stale periods',
    () {
      final first = DayEntry(date: day(26), flow: FlowIntensity.light);
      final next = DayEntry(date: day(27), flow: FlowIntensity.medium);
      expect(timeline([first, next]).periods.single.start, day(26));
      expect(timeline([next]).periods.single.start, day(27));
      expect(
        timeline([DayEntry(date: day(26), flow: FlowIntensity.none)]).periods,
        isEmpty,
      );
      expect(timeline([]).periods, isEmpty);
    },
  );
  test('No-flow logs preserve manually recorded periods unchanged', () {
    final records = [
      Period(id: 'a', start: day(1), isOngoing: true),
      Period(id: 'b', start: day(24), isOngoing: true),
    ];
    final t = timeline([
      DayEntry(date: day(26), mood: Mood.good),
    ], periods: records);
    expect(t.periods.length, 2);
    expect(t.periods.every((p) => p.isOngoing), isTrue);
    expect(t.logAdjustedIds, isEmpty);
  });
  test('Same-day None never makes a period end precede its manual start', () {
    final t = timeline(
      [DayEntry(date: day(28), flow: FlowIntensity.none)],
      periods: [Period(id: 'a', start: day(28), isOngoing: true)],
    );
    expect(t.periods.single.end, day(28));
    expect(
      PeriodDayOverview.fromPeriods(
        t.periods,
        day(28),
        bleedingAbsent: true,
      ).isPeriod,
      isFalse,
    );
  });
  test(
    'Three log starts provide the same personal countdown as manual starts',
    () {
      final entries = [
        for (final date in [
          CalendarDate(2026, 8, 30),
          CalendarDate(2026, 9, 27),
          CalendarDate(2026, 10, 25),
        ]) ...[
          DayEntry(date: date, flow: FlowIntensity.light),
          DayEntry(date: date.addDays(2), flow: FlowIntensity.none),
        ],
      ];
      final t = timeline(entries);
      final overview = PeriodDayOverview.fromPeriods(t.periods, day(28));
      expect(overview.estimate!.lengthInDays, 28);
      expect(overview.daysToNext, 25);
      expect(overview.hasCountdown, isTrue);
    },
  );
}
