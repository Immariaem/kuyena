import 'calendar_date.dart';
import 'period_day_overview.dart';

enum CyclePhase { menstruation, follicular, aroundOvulation, luteal, unknown }

enum PhaseUnknownReason {
  noPeriod,
  conflictingPeriods,
  unknownEnd,
  insufficientHistory,
  predictionReached,
  incompatibleDates,
  dateOutOfRange,
}

/// A replaceable calendar approximation for the Home prototype.
/// Only menstruation comes from recorded bleeding. Other phases are estimates;
/// neither an ovulation nor a fertile window is detected or stored.
final class CyclePhaseOverview {
  const CyclePhaseOverview._(
    this.phase, {
    this.unknownReason,
    this.earliestOvulation,
    this.latestOvulation,
  });

  factory CyclePhaseOverview.fromDay(PeriodDayOverview day) {
    if (day.kind == PeriodDayKind.overlapping) {
      return const CyclePhaseOverview._(
        CyclePhase.unknown,
        unknownReason: PhaseUnknownReason.conflictingPeriods,
      );
    }
    if (day.isPeriod) {
      return const CyclePhaseOverview._(CyclePhase.menstruation);
    }
    if (day.period == null) {
      return const CyclePhaseOverview._(
        CyclePhase.unknown,
        unknownReason: PhaseUnknownReason.noPeriod,
      );
    }
    if (day.kind == PeriodDayKind.unknownEnd) {
      return const CyclePhaseOverview._(
        CyclePhase.unknown,
        unknownReason: PhaseUnknownReason.unknownEnd,
      );
    }
    final estimate = day.estimate;
    if (estimate == null) {
      return const CyclePhaseOverview._(
        CyclePhase.unknown,
        unknownReason: PhaseUnknownReason.insufficientHistory,
      );
    }
    if (day.date.compareTo(estimate.expectedStart) >= 0) {
      // Do not invent a new cycle or repeat a stale luteal phase indefinitely.
      return const CyclePhaseOverview._(
        CyclePhase.unknown,
        unknownReason: PhaseUnknownReason.predictionReached,
      );
    }
    try {
      // Provisional broad range, not an exact ovulation day. Keep these rules
      // here so the agreed project calculation can replace them later.
      final earliest = estimate.expectedStart.addDays(-16);
      final latest = estimate.expectedStart.addDays(-10);
      final end = day.period!.end;
      if (earliest.compareTo(day.period!.start) <= 0 ||
          (end != null && earliest.compareTo(end) <= 0)) {
        return const CyclePhaseOverview._(
          CyclePhase.unknown,
          unknownReason: PhaseUnknownReason.incompatibleDates,
        );
      }
      return CyclePhaseOverview._(
        day.date.compareTo(earliest) < 0
            ? CyclePhase.follicular
            : day.date.compareTo(latest) <= 0
            ? CyclePhase.aroundOvulation
            : CyclePhase.luteal,
        earliestOvulation: earliest,
        latestOvulation: latest,
      );
    } on FormatException {
      return const CyclePhaseOverview._(
        CyclePhase.unknown,
        unknownReason: PhaseUnknownReason.dateOutOfRange,
      );
    }
  }

  final CyclePhase phase;
  final PhaseUnknownReason? unknownReason;
  final CalendarDate? earliestOvulation;
  final CalendarDate? latestOvulation;

  bool get isEstimated =>
      phase != CyclePhase.unknown && phase != CyclePhase.menstruation;
}
