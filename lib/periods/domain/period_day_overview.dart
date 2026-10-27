import 'calendar_date.dart';
import 'cycle_estimate.dart';
import 'period.dart';

/// Display cases for documented dates, not biological cycle phases.
enum PeriodDayKind {
  noEntry,
  unknownEnd,
  ongoingPeriod,
  documentedPeriod,
  afterPeriod,
  overlapping,
}

/// A computed view. It is never stored as another source of truth.
final class PeriodDayOverview {
  const PeriodDayOverview._(this.date, this.period, this.kind, this.estimate);

  factory PeriodDayOverview.fromPeriods(
    Iterable<Period> periods,
    CalendarDate date, {
    CalendarDate? asOf,
  }) {
    final observationDay = asOf ?? date;
    final earlier =
        periods
            .where(
              (p) =>
                  p.start.compareTo(date) <= 0 &&
                  p.start.compareTo(observationDay) <= 0,
            )
            .toList()
          ..sort((a, b) => b.start.compareTo(a.start));
    if (earlier.isEmpty) {
      return PeriodDayOverview._(date, null, PeriodDayKind.noEntry, null);
    }
    final latest = earlier.first;
    // Conflicting documented ranges are shown for review, not silently resolved.
    if (earlier
        .skip(1)
        .any((p) => p.end != null && p.end!.compareTo(date) >= 0)) {
      return PeriodDayOverview._(date, latest, PeriodDayKind.overlapping, null);
    }
    final end = latest.end;
    return PeriodDayOverview._(
      date,
      latest,
      latest.isOngoing && date.compareTo(observationDay) <= 0
          ? PeriodDayKind.ongoingPeriod
          : end == null
          ? PeriodDayKind.unknownEnd
          : date.compareTo(end) <= 0
          ? PeriodDayKind.documentedPeriod
          : PeriodDayKind.afterPeriod,
      CycleEstimate.fromPeriods(earlier),
    );
  }

  final CalendarDate date;
  final Period? period;
  final PeriodDayKind kind;
  final CycleEstimate? estimate;

  bool get isPeriod =>
      kind == PeriodDayKind.documentedPeriod ||
      kind == PeriodDayKind.ongoingPeriod;
  bool get hasCountdown =>
      !isPeriod && kind != PeriodDayKind.overlapping && estimate != null;
  int? get daysToNext =>
      estimate == null ? null : date.daysUntil(estimate!.expectedStart);

  int? get dayNumber =>
      period == null ? null : period!.start.daysUntil(date) + 1;
  int? get documentedDuration =>
      period?.end == null ? null : period!.start.daysUntil(period!.end!) + 1;

  /// Starts empty on day 1, then grows clockwise. Never invents a duration.
  double? get progress {
    if (kind == PeriodDayKind.overlapping || dayNumber == null) return null;
    if (estimate != null) {
      return ((dayNumber! - 1) / estimate!.lengthInDays).clamp(0.0, 1.0);
    }
    if (kind == PeriodDayKind.documentedPeriod) {
      final duration = documentedDuration!;
      return duration == 1 ? 0 : (dayNumber! - 1) / (duration - 1);
    }
    return null;
  }
}
