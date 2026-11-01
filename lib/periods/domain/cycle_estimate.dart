import 'calendar_date.dart';
import 'period.dart';

enum CycleEstimateSource { populationReference, selfReported, observedMean }

/// A transparent calendar estimate, never an ovulation measurement.
final class CycleEstimate {
  const CycleEstimate._({
    required this.expectedStart,
    required this.source,
    required this.lengthInDays,
    required this.cycleCount,
    required this.shortestInterval,
    required this.longestInterval,
    required this.meanLengthInDays,
  });
  static CycleEstimate? fromPeriods(
    Iterable<Period> periods, {
    int? initialLength,
  }) {
    final sorted = periods.toList()..sort((a, b) => a.start.compareTo(b.start));
    if (sorted.isEmpty) return null;
    final lengths = <int>[];
    for (var i = 1; i < sorted.length; i++) {
      final previous = sorted[i - 1], next = sorted[i];
      final length = previous.start.daysUntil(next.start);
      if (length <= 0 ||
          previous.isOngoing ||
          (previous.end != null && previous.end!.compareTo(next.start) >= 0)) {
        return null;
      }
      lengths.add(length);
    }
    if (initialLength != null && (initialLength < 1 || initialLength > 366)) {
      return null;
    }
    final mean = lengths.isEmpty
        ? (initialLength ?? 28).toDouble()
        : lengths.reduce((a, b) => a + b) / lengths.length;
    final typical = mean.round();
    lengths.sort();
    try {
      return CycleEstimate._(
        expectedStart: sorted.last.start.addDays(typical),
        source: lengths.isNotEmpty
            ? CycleEstimateSource.observedMean
            : initialLength != null
            ? CycleEstimateSource.selfReported
            : CycleEstimateSource.populationReference,
        lengthInDays: typical,
        meanLengthInDays: mean,
        cycleCount: lengths.length,
        shortestInterval: lengths.isEmpty ? typical : lengths.first,
        longestInterval: lengths.isEmpty ? typical : lengths.last,
      );
    } on FormatException {
      return null;
    }
  }

  final CalendarDate expectedStart;
  final CycleEstimateSource source;
  final int lengthInDays, cycleCount, shortestInterval, longestInterval;
  final double meanLengthInDays;
  bool get isInitial => cycleCount == 0;
  bool get isPopulationReference =>
      source == CycleEstimateSource.populationReference;
  CalendarDate? get earliestOvulation {
    try {
      return expectedStart.addDays(-16);
    } on FormatException {
      return null;
    }
  }

  CalendarDate? get latestOvulation {
    try {
      return expectedStart.addDays(-10);
    } on FormatException {
      return null;
    }
  }

  String get basisLabel => isPopulationReference
      ? 'Allgemeiner Startwert: 28 Tage'
      : isInitial
      ? 'Dein Richtwert: $lengthInDays Tage'
      : 'Persönlicher Mittelwert: $lengthInDays Tage · $cycleCount ${cycleCount == 1 ? "Startabstand" : "Startabstände"}';
}
