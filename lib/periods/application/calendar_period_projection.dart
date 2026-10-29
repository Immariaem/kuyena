import '../domain/calendar_date.dart';
import '../domain/period.dart';

/// Applies explicitly selected days without splitting a recorded cycle when
/// one interior day is removed. Calendar-only adjacent days form one period.
List<Period> projectCalendarDays({
  required List<Period> periods,
  required Map<CalendarDate, bool> changes,
  required Set<String> manualIds,
  required CalendarDate asOf,
}) {
  final edits = Map<CalendarDate, bool>.fromEntries(
    changes.entries.where((e) => e.key.compareTo(asOf) <= 0),
  );
  final result = <Period>[];
  final reserved = periods.map((p) => p.id).toSet();
  for (final period in periods) {
    var first = period.start;
    var ongoing = period.isOngoing;
    var last = period.end ?? (ongoing ? asOf : first);
    var knownEnd = period.end != null;
    if (ongoing) {
      final relevant =
          edits.keys
              .where((d) => d.compareTo(first) >= 0 && d.compareTo(last) <= 0)
              .toList()
            ..sort();
      if (relevant.isNotEmpty && edits[relevant.last] == false) {
        if (relevant.last == first) continue;
        last = relevant.last.addDays(-1);
        ongoing = false;
        knownEnd = true;
      }
    }
    final excluded = <CalendarDate>{
      ...period.excludedDays.where((d) => edits[d] != true),
      ...edits.entries
          .where(
            (e) =>
                !e.value &&
                e.key.compareTo(first) >= 0 &&
                e.key.compareTo(last) <= 0,
          )
          .map((e) => e.key),
    };
    var empty = false;
    while (excluded.contains(first)) {
      if (first == last) {
        empty = true;
        break;
      }
      first = first.addDays(1);
    }
    if (empty) continue;
    while (excluded.contains(last)) {
      if (first == last) {
        empty = true;
        break;
      }
      last = last.addDays(-1);
    }
    if (empty || first.compareTo(last) > 0) continue;
    result.add(
      Period(
        id: period.id,
        start: first,
        end: knownEnd ? last : null,
        isOngoing: ongoing,
        excludedDays: excluded
            .where((d) => d.compareTo(first) >= 0 && d.compareTo(last) <= 0)
            .toSet(),
      ),
    );
  }

  // Consecutive correction keys retain the identity of a calendar period,
  // even after an interior previously-selected day is switched off.
  final dates = edits.keys.toList()..sort();
  final runs = <List<CalendarDate>>[];
  for (final date in dates) {
    if (runs.isEmpty || runs.last.last.daysUntil(date) != 1) {
      runs.add(<CalendarDate>[]);
    }
    runs.last.add(date);
  }
  CalendarDate lastOf(Period p) => p.end ?? (p.isOngoing ? asOf : p.start);
  for (final run in runs) {
    final selected = run.where((d) => edits[d] == true).toList();
    if (selected.isEmpty) continue;
    final from = selected.first, to = selected.last;
    if (result.any(
      (p) => p.start.compareTo(from) <= 0 && lastOf(p).compareTo(to) >= 0,
    )) {
      continue;
    }
    final adjacent =
        result
            .where(
              (p) =>
                  from.daysUntil(lastOf(p)) >= -1 &&
                  p.start.daysUntil(to) >= -1,
            )
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    String id;
    if (adjacent.isEmpty) {
      id = 'calendar-period-${from.iso}';
      while (reserved.contains(id)) {
        id = 'calendar-$id';
      }
      reserved.add(id);
    } else {
      final manual = adjacent.where((p) => manualIds.contains(p.id));
      id = manual.isNotEmpty ? manual.first.id : adjacent.first.id;
    }
    var first = from, last = to;
    final excluded = <CalendarDate>{};
    for (final p in adjacent) {
      if (p.start.compareTo(first) < 0) first = p.start;
      if (lastOf(p).compareTo(last) > 0) last = lastOf(p);
      excluded.addAll(p.excludedDays);
    }
    excluded.addAll(
      edits.entries
          .where(
            (e) =>
                !e.value &&
                e.key.compareTo(first) >= 0 &&
                e.key.compareTo(last) <= 0,
          )
          .map((e) => e.key),
    );
    excluded.removeAll(selected);
    final ongoing = adjacent.any((p) => p.isOngoing);
    result.removeWhere((p) => adjacent.contains(p));
    result.add(
      Period(
        id: id,
        start: first,
        end: ongoing ? null : last,
        isOngoing: ongoing,
        excludedDays: excluded,
      ),
    );
  }
  result.sort((a, b) => b.start.compareTo(a.start));
  return List.unmodifiable(result);
}
