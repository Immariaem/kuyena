import 'calendar_date.dart';
import 'period.dart';

/// A transparent calendar estimate, never an ovulation measurement.
final class CycleEstimate {
  const CycleEstimate._({
    required this.expectedStart,
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
    if (lengths.isEmpty &&
        (initialLength == null || initialLength < 1 || initialLength > 366)) {
      return null;
    }
    final mean = lengths.isEmpty
        ? initialLength!.toDouble()
        : lengths.reduce((a, b) => a + b) / lengths.length;
    final typical = mean.round();
    lengths.sort();
    try {
      return CycleEstimate._(
        expectedStart: sorted.last.start.addDays(typical),
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
  final int lengthInDays, cycleCount, shortestInterval, longestInterval;
  final double meanLengthInDays;
  bool get isInitial => cycleCount == 0;
}
