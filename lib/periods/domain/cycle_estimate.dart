import 'calendar_date.dart';
import 'period.dart';

/// A transparent prototype estimate, not a guaranteed next start date.
final class CycleEstimate {
  const CycleEstimate._({
    required this.expectedStart,
    required this.lengthInDays,
    required this.cycleCount,
    required this.shortestInterval,
    required this.longestInterval,
  });

  static CycleEstimate? fromPeriods(Iterable<Period> periods) {
    final sorted = periods.toList()..sort((a, b) => b.start.compareTo(a.start));
    // Two complete start-to-start intervals require at least three starts.
    if (sorted.length < 3) return null;
    final recent = sorted.take(7).toList().reversed.toList();
    final lengths = <int>[];
    for (var i = 1; i < recent.length; i++) {
      final previous = recent[i - 1];
      final next = recent[i];
      final length = previous.start.daysUntil(next.start);
      if (length <= 0 ||
          (previous.end != null && previous.end!.compareTo(next.start) >= 0)) {
        return null;
      }
      lengths.add(length);
    }
    lengths.sort();
    final middle = lengths.length ~/ 2;
    final typical = lengths.length.isOdd
        ? lengths[middle]
        : ((lengths[middle - 1] + lengths[middle]) / 2).round();
    try {
      return CycleEstimate._(
        expectedStart: sorted.first.start.addDays(typical),
        lengthInDays: typical,
        cycleCount: lengths.length,
        shortestInterval: lengths.first,
        longestInterval: lengths.last,
      );
    } on FormatException {
      return null;
    }
  }

  final CalendarDate expectedStart;
  final int lengthInDays;
  final int cycleCount;
  final int shortestInterval;
  final int longestInterval;
}
