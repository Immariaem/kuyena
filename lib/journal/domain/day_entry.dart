import '../../periods/domain/calendar_date.dart';

enum FlowIntensity { none, light, medium, heavy }

enum Symptom { cramps, headache, fatigue, breastTenderness }

enum Mood { good, okay, low }

/// One editable observation per calendar day, independent of any period.
final class DayEntry {
  DayEntry({
    required this.date,
    this.flow,
    Set<Symptom> symptoms = const {},
    this.mood,
    this.energy,
    this.note = '',
  }) : symptoms = Set.unmodifiable(symptoms) {
    if (energy != null && (energy! < 0 || energy! > 100)) {
      throw ArgumentError('Energy must be between 0 and 100.');
    }
  }
  final CalendarDate date;
  final FlowIntensity? flow;
  final Set<Symptom> symptoms;
  final Mood? mood;
  final int? energy;
  final String note;
  bool get isEmpty =>
      flow == null &&
      symptoms.isEmpty &&
      mood == null &&
      energy == null &&
      note.trim().isEmpty;
  Map<String, Object?> toJson() => {
    'date': date.iso,
    'flow': flow?.name,
    'symptoms': symptoms.map((s) => s.name).toList()..sort(),
    'mood': mood?.name,
    'energy': energy,
    'note': note,
  };
  factory DayEntry.fromJson(Map<String, dynamic> json) {
    if (json['date'] is! String ||
        json['symptoms'] is! List ||
        json['note'] is! String ||
        !json.containsKey('flow') ||
        !json.containsKey('mood') ||
        !json.containsKey('energy') ||
        (json['energy'] != null && json['energy'] is! int)) {
      throw const FormatException('Invalid day entry.');
    }
    final symptoms = (json['symptoms'] as List)
        .map((s) => Symptom.values.byName(s as String))
        .toList();
    if (symptoms.toSet().length != symptoms.length) {
      throw const FormatException('Duplicate symptom.');
    }
    return DayEntry(
      date: CalendarDate.parse(json['date'] as String),
      flow: json['flow'] == null
          ? null
          : FlowIntensity.values.byName(json['flow'] as String),
      symptoms: symptoms.toSet(),
      mood: json['mood'] == null
          ? null
          : Mood.values.byName(json['mood'] as String),
      energy: json['energy'] as int?,
      note: json['note'] as String,
    );
  }
}

final class JournalData {
  JournalData({List<DayEntry> entries = const [], this.reminders = false})
    : entries = List.unmodifiable(entries);
  final List<DayEntry> entries;
  final bool reminders;
  DayEntry? entryFor(CalendarDate date) {
    for (final entry in entries) {
      if (entry.date == date) return entry;
    }
    return null;
  }
}
