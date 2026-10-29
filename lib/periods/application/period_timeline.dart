import '../../journal/domain/day_entry.dart';
import '../domain/calendar_date.dart';
import '../domain/period.dart';
import 'calendar_period_projection.dart';

/// One computed timeline for Home, Calendar and Cycle. The two original
/// documents are never rewritten or duplicated while reconciling observations.
final class PeriodTimeline {
  PeriodTimeline._(
    this.periods,
    this.logPeriodIds,
    this.logAdjustedIds,
    this.calendarPeriodIds,
  );
  final List<Period> periods;
  final Set<String> logPeriodIds;
  final Set<String> logAdjustedIds;
  final Set<String> calendarPeriodIds;

  factory PeriodTimeline.from({
    required Iterable<Period> periods,
    required Iterable<DayEntry> entries,
    required CalendarDate asOf,
    Map<CalendarDate, bool> periodDays = const {},
  }) {
    final manual = periods.where((p) => p.start.compareTo(asOf) <= 0).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final flows =
        entries
            .where((e) => e.flow != null && e.date.compareTo(asOf) <= 0)
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final result = <Period>[];
    final logIds = <String>{}, adjusted = <String>{};
    final reserved = manual.map((p) => p.id).toSet();
    int nextManual = 0;
    Period? current;
    void replace(Period updated, {bool logAdjustment = false}) {
      final index = result.indexWhere((p) => p.id == updated.id);
      if (index < 0) {
        result.add(updated);
      } else {
        result[index] = updated;
      }
      current = updated;
      if (logAdjustment && !logIds.contains(updated.id)) {
        adjusted.add(updated.id);
      }
    }

    void acceptManual(Period p) {
      // A new recorded start is a new cycle anchor. Do not invent an end date
      // for an earlier still-open record.
      if (current?.isOngoing == true &&
          (logIds.contains(current!.id) || adjusted.contains(current!.id))) {
        final previous = current!;
        replace(Period(id: previous.id, start: previous.start));
      }
      result.add(p);
      current = p;
    }

    for (final entry in flows) {
      while (nextManual < manual.length &&
          manual[nextManual].start.compareTo(entry.date) <= 0) {
        acceptManual(manual[nextManual++]);
      }
      final active = current;
      if (entry.flow == FlowIntensity.none) {
        if (active != null &&
            (active.end == null || active.end!.compareTo(entry.date) >= 0)) {
          final last = entry.date == active.start
              ? active.start
              : entry.date.addDays(-1);
          replace(
            Period(id: active.id, start: active.start, end: last),
            logAdjustment: true,
          );
        }
      } else {
        if (active != null &&
            (active.end == null || active.end!.compareTo(entry.date) >= 0)) {
          if (active.end == null && !active.isOngoing) {
            replace(
              Period(id: active.id, start: active.start, isOngoing: true),
              logAdjustment: true,
            );
          }
        } else {
          var id = 'log-period-${entry.date.iso}';
          while (reserved.contains(id)) {
            id = 'log-$id';
          }
          reserved.add(id);
          logIds.add(id);
          replace(Period(id: id, start: entry.date, isOngoing: true));
        }
      }
    }
    while (nextManual < manual.length) {
      acceptManual(manual[nextManual++]);
    }
    result.sort((a, b) => b.start.compareTo(a.start));
    final projected = periodDays.isEmpty
        ? result
        : projectCalendarDays(
            periods: result,
            changes: periodDays,
            manualIds: manual.map((p) => p.id).toSet(),
            asOf: asOf,
          );
    final ids = projected.map((p) => p.id).toSet();
    return PeriodTimeline._(
      List.unmodifiable(projected),
      Set.unmodifiable(logIds.intersection(ids)),
      Set.unmodifiable(adjusted.intersection(ids)),
      Set.unmodifiable(
        ids.difference(manual.map((p) => p.id).toSet()).difference(logIds),
      ),
    );
  }
}
