import 'dart:convert';
import '../../periods/data/local_period_repository.dart';
import '../domain/day_entry.dart';

final class JournalDataException implements Exception {
  const JournalDataException();
}

final class LocalJournalRepository {
  const LocalJournalRepository(this.storage);
  final PeriodStorage storage;
  Future<JournalData> load() async {
    final raw = await storage.read();
    if (raw == null) return JournalData();
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic> ||
          json['version'] != 1 ||
          json['entries'] is! List ||
          json['reminders'] is! bool) {
        throw const JournalDataException();
      }
      final entries = (json['entries'] as List)
          .map((e) => DayEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      if (entries.map((e) => e.date).toSet().length != entries.length) {
        throw const JournalDataException();
      }
      entries.sort((a, b) => b.date.compareTo(a.date));
      return JournalData(
        entries: entries,
        reminders: json['reminders'] as bool,
      );
    } on FormatException {
      throw const JournalDataException();
    } on ArgumentError {
      throw const JournalDataException();
    } on TypeError {
      throw const JournalDataException();
    }
  }

  Future<void> save(JournalData data) async {
    if (data.entries.map((e) => e.date).toSet().length != data.entries.length) {
      throw const JournalDataException();
    }
    final raw = jsonEncode({
      'version': 1,
      'reminders': data.reminders,
      'entries': data.entries.map((e) => e.toJson()).toList(),
    });
    await storage.write(raw);
    if (await storage.read() != raw) throw StateError('Save not confirmed.');
  }

  Future<void> clear() async {
    await storage.delete();
    if (await storage.read() != null) throw StateError('Delete not confirmed.');
  }
}
