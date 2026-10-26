import 'calendar_date.dart';

/// Eine dokumentierte Periode mit einer beim Korrigieren stabilen Kennung.
final class Period {
  Period({required this.id, required this.start, this.end}) {
    if (id.trim().isEmpty) {
      throw ArgumentError('Eine Periode benötigt eine Kennung.');
    }
    final endDate = end;
    if (endDate != null && endDate.compareTo(start) < 0) {
      throw ArgumentError('Das Periodenende darf nicht vor dem Beginn liegen.');
    }
  }

  final String id;
  final CalendarDate start;

  /// Ein fehlendes Ende bedeutet unbekannt, nicht zwingend laufende Blutung.
  final CalendarDate? end;

  /// Gibt eine geprüfte Korrektur mit derselben Kennung zurück.
  /// Beide Datumsangaben sind ausdrücklich nötig; null entfernt das Ende.
  Period correctDates({
    required CalendarDate start,
    required CalendarDate? end,
  }) => Period(id: id, start: start, end: end);
}
