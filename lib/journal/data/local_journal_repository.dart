import 'dart:convert';
import '../../periods/data/local_period_repository.dart';
import '../../periods/domain/calendar_date.dart';
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
    return decode(raw);
  }

  static JournalData decode(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic> ||
          (json['version'] != 1 && json['version'] != 2) ||
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
      final periodDays = <CalendarDate, bool>{};
      if (json['version'] == 2) {
        if (json['periodDays'] is! List) throw const JournalDataException();
        for (final item in json['periodDays'] as List) {
          if (item is! Map<String, dynamic> ||
              item['date'] is! String ||
              item['period'] is! bool) {
            throw const JournalDataException();
          }
          final date = CalendarDate.parse(item['date'] as String);
          if (periodDays.containsKey(date)) throw const JournalDataException();
          periodDays[date] = item['period'] as bool;
        }
      }
      return JournalData(
        periodDays: periodDays,
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
    final raw = encode(data);
    await storage.write(raw);
    if (await storage.read() != raw) throw StateError('Save not confirmed.');
  }

  static String encode(JournalData data) {
    if (data.entries.map((e) => e.date).toSet().length != data.entries.length) {
      throw const JournalDataException();
    }
    return jsonEncode({
      'version': 2,
      'periodDays': [
        for (final date in data.periodDays.keys.toList()..sort())
          {'date': date.iso, 'period': data.periodDays[date]},
      ],
      'reminders': data.reminders,
      'entries': data.entries.map((e) => e.toJson()).toList(),
    });
  }

  Future<void> clear() async {
    await storage.delete();
    if (await storage.read() != null) throw StateError('Delete not confirmed.');
  }
}
