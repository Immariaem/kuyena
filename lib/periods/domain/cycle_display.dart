import 'calendar_date.dart';
import 'period_day_overview.dart';
import 'period.dart';

enum CycleDayType { period, estimatedOvulation, estimatedFertile, rest }

/// Read-only calendar projection shared by the wheel and calendar.
/// Estimated days never become stored bleeding or a newly invented cycle.
final class CycleDisplay {
  CycleDisplay.fromDay(
    this.day, {
    CalendarDate? asOf,
    Iterable<Period> history = const [],
    String? periodLengthPreference,
  }) {
    final period = day.period, estimate = day.estimate;
    if (period == null || estimate == null) return;
    final observedThrough = asOf ?? day.date;
    final first = estimate.earliestOvulation, last = estimate.latestOvulation;
    final recordedEnd =
        period.end ?? (period.isOngoing ? observedThrough : period.start);
    if (day.kind != PeriodDayKind.unknownEnd &&
        first != null &&
        last != null &&
        first.compareTo(recordedEnd) > 0 &&
        first.compareTo(period.start) > 0) {
      ovulationStart = first;
      ovulationEnd = last;
      try {
        final firstFertile = first.addDays(-5);
        fertileStart = firstFertile.compareTo(period.start) < 0
            ? period.start
            : firstFertile;
      } on FormatException {
        fertileStart = period.start;
      }
    }
    days = List.unmodifiable([
      for (var i = 0; i < estimate.lengthInDays; i++)
        period.includes(period.start.addDays(i), asOf: observedThrough)
            ? CycleDayType.period
            : isOvulationDay(period.start.addDays(i))
            ? CycleDayType.estimatedOvulation
            : isFertileDay(period.start.addDays(i))
            ? CycleDayType.estimatedFertile
            : CycleDayType.rest,
    ]);
    final completed = (history.isEmpty ? [period] : history)
        .where(
          (p) =>
              p.end != null &&
              p.end!.compareTo(observedThrough) <= 0 &&
              p.start.compareTo(observedThrough) <= 0 &&
              (p.documentedDayCount ?? 0) > 0,
        )
        .toList();
    if (completed.isNotEmpty) {
      periodDuration =
          (completed.fold<int>(0, (n, p) => n + p.documentedDayCount!) /
                  completed.length)
              .round();
      durationBasis =
          'Mittlere eingetragene Periodendauer: $periodDuration ${periodDuration == 1 ? "Tag" : "Tage"}';
    } else {
      periodDuration = switch (periodLengthPreference) {
        'single' => 1,
        'short' => 3,
        'medium' => 5,
        'long' => 7,
        'extended' => 8,
        _ => 5,
      };
      durationBasis = switch (periodLengthPreference) {
        'single' => 'Deine Angabe: 1 Tag',
        'short' => 'Deine Angabe: 2–3 Tage · bis zum 3. Tag markiert',
        'medium' => 'Deine Angabe: 4–5 Tage · bis zum 5. Tag markiert',
        'long' => 'Deine Angabe: 6–7 Tage · bis zum 7. Tag markiert',
        'extended' =>
          'Deine Angabe: 8+ Tage · zunächst 8 Tage markiert, Ende offen',
        _ => 'Vorläufige Annahme ohne eigene Dauer: 5 Tage',
      };
      periodEndOpen = periodLengthPreference == 'extended';
    }
    nextPeriodStart = estimate.expectedStart;
    try {
      nextPeriodEnd = nextPeriodStart!.addDays(periodDuration! - 1);
    } on FormatException {
      nextPeriodEnd = null;
    }
    final index = period.start.daysUntil(day.date);
    // A late estimate does not restart the wheel at a fictional new cycle.
    if (index >= 0 && index < days.length) selectedIndex = index;
  }

  final PeriodDayOverview day;
  List<CycleDayType> days = const [];
  CalendarDate? ovulationStart, ovulationEnd, fertileStart;
  CalendarDate? nextPeriodStart, nextPeriodEnd;
  int? periodDuration;
  String? durationBasis;
  bool periodEndOpen = false;
  int? selectedIndex;
  bool isOvulationDay(CalendarDate date) =>
      ovulationStart != null &&
      date.compareTo(ovulationStart!) >= 0 &&
      date.compareTo(ovulationEnd!) <= 0;
  bool isFertileDay(CalendarDate date) =>
      fertileStart != null &&
      date.compareTo(fertileStart!) >= 0 &&
      date.compareTo(ovulationEnd!) <= 0;
  Set<CalendarDate> get fertileDays => {
    if (fertileStart != null)
      for (var i = 0; i <= fertileStart!.daysUntil(ovulationEnd!); i++)
        fertileStart!.addDays(i),
  };
  Set<CalendarDate> get expectedPeriodDays => {
    if (nextPeriodStart != null)
      for (var i = 0; i < (nextPeriodEnd == null ? 1 : periodDuration!); i++)
        nextPeriodStart!.addDays(i),
  };
  int? get daysToOvulation =>
      ovulationStart == null ? null : day.date.daysUntil(ovulationStart!);
  bool get beforeOvulation => daysToOvulation != null && daysToOvulation! > 0;
  bool get inOvulationWindow => isOvulationDay(day.date);
  Set<CalendarDate> get ovulationDays => {
    if (ovulationStart != null)
      for (var i = 0; i <= ovulationStart!.daysUntil(ovulationEnd!); i++)
        ovulationStart!.addDays(i),
  };
}
