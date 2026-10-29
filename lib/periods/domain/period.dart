import 'calendar_date.dart';

/// Eine dokumentierte Periode mit einer beim Korrigieren stabilen Kennung.
final class Period {
  Period({
    required this.id,
    required this.start,
    this.end,
    this.isOngoing = false,
    Set<CalendarDate> excludedDays = const {},
  }) : excludedDays = Set.unmodifiable(excludedDays) {
    if (id.trim().isEmpty) {
      throw ArgumentError('Eine Periode benötigt eine Kennung.');
    }
    final endDate = end;
    if (isOngoing && endDate != null) {
      throw ArgumentError(
        'Eine laufende Periode kann noch kein Enddatum haben.',
      );
    }
    if (endDate != null && endDate.compareTo(start) < 0) {
      throw ArgumentError('Das Periodenende darf nicht vor dem Beginn liegen.');
    }
  }

  final String id;
  final CalendarDate start;

  /// Ein fehlendes Ende bedeutet unbekannt, nicht zwingend laufende Blutung.
  final CalendarDate? end;

  /// Explicitly reported by the person; never inferred from a missing end.
  final bool isOngoing;

  /// Computed from calendar corrections, stored separately in the journal.
  final Set<CalendarDate> excludedDays;
  bool includes(CalendarDate date, {required CalendarDate asOf}) =>
      !excludedDays.contains(date) &&
      start.compareTo(date) <= 0 &&
      (end != null
          ? date.compareTo(end!) <= 0
          : isOngoing
          ? date.compareTo(asOf) <= 0
          : date == start);
  int? get documentedDayCount => end == null
      ? null
      : start.daysUntil(end!) +
            1 -
            excludedDays
                .where((d) => d.compareTo(start) >= 0 && d.compareTo(end!) <= 0)
                .length;

  /// Gibt eine geprüfte Korrektur mit derselben Kennung zurück.
  /// Beide Datumsangaben sind ausdrücklich nötig; null entfernt das Ende.
  Period correctDates({
    required CalendarDate start,
    required CalendarDate? end,
    bool? isOngoing,
  }) => Period(
    id: id,
    start: start,
    end: end,
    isOngoing: isOngoing ?? (end == null && this.isOngoing),
  );
}
