import '../../profile/domain/user_profile.dart';
import 'dart:convert';
import '../../journal/data/local_journal_repository.dart';
import '../../journal/domain/day_entry.dart';
import '../../periods/data/local_period_repository.dart';
import '../../periods/domain/calendar_date.dart';
import '../../periods/domain/period.dart';

final class BackupException implements Exception {
  const BackupException(this.message);
  final String message;
}

final class BackupDocument {
  BackupDocument({
    required List<Period> periods,
    required this.journal,
    this.profile,
  }) : periods = List.unmodifiable(periods);
  static const maxBytes = 8 * 1024 * 1024;
  static const maxRecords = 50000;
  final List<Period> periods;
  final JournalData journal;
  final UserProfile? profile;
  String encode() => const JsonEncoder.withIndent('  ').convert({
    'format': 'kuyena-export',
    'version': 3,
    'profile': profile?.toJson(),
    'periods': [
      for (final p in periods)
        {
          'id': p.id,
          'start': p.start.iso,
          'end': p.end?.iso,
          'ongoing': p.isOngoing,
        },
    ],
    'dayEntries': [for (final e in journal.entries) e.toJson()],
    'periodDays': [
      for (final d in journal.periodDays.keys.toList()..sort())
        {'date': d.iso, 'period': journal.periodDays[d]},
    ],
    'reminders': journal.reminders,
  });
  static BackupDocument decode(String raw, {required CalendarDate today}) {
    if (utf8.encode(raw).length > maxBytes) {
      throw const BackupException(
        'Die Sicherung ist zu groß. Maximal 8 MB sind erlaubt.',
      );
    }
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic> ||
          json['format'] != 'kuyena-export' ||
          (json['version'] != 1 &&
              json['version'] != 2 &&
              json['version'] != 3) ||
          json['periods'] is! List ||
          json['dayEntries'] is! List ||
          json['reminders'] is! bool ||
          (json['version'] != 1 && json['periodDays'] is! List) ||
          (json['version'] == 3 && !json.containsKey('profile'))) {
        throw const FormatException();
      }
      final periodsJson = json['periods'] as List,
          entries = json['dayEntries'] as List;
      final corrections = json['version'] == 1
          ? <dynamic>[]
          : json['periodDays'] as List;
      if (periodsJson.length + entries.length + corrections.length >
          maxRecords) {
        throw const FormatException();
      }
      final periods = LocalPeriodRepository.decode(
        jsonEncode({
          'version': 3,
          'periods': [
            for (final p in periodsJson)
              if (p is Map<String, dynamic>)
                {
                  ...p,
                  if (json['version'] == 1 && !p.containsKey('ongoing'))
                    'ongoing': false,
                }
              else
                throw const FormatException(),
          ],
        }),
      );
      final journal = LocalJournalRepository.decode(
        jsonEncode({
          'version': 2,
          'entries': entries,
          'reminders': json['reminders'],
          'periodDays': corrections,
        }),
      );
      if (periods.any(
            (p) =>
                p.start.compareTo(today) > 0 ||
                (p.end != null && p.end!.compareTo(today) > 0),
          ) ||
          journal.entries.any(
            (e) => e.date.compareTo(today) > 0 || e.isEmpty,
          ) ||
          journal.periodDays.keys.any((d) => d.compareTo(today) > 0)) {
        throw const FormatException();
      }
      // No new assumptions about cycle lengths or overlaps during import.
      // Existing reviewable conflicts are preserved and displayed as before.
      final profile = json['version'] == 3 && json['profile'] != null
          ? UserProfile.decode(jsonEncode(json['profile']))
          : null;
      if (profile?.lastPeriodStart != null &&
          profile!.lastPeriodStart!.compareTo(today) > 0) {
        throw const FormatException();
      }
      return BackupDocument(
        periods: periods,
        journal: journal,
        profile: profile,
      );
    } on FormatException {
      throw const BackupException(
        'Diese Datei ist keine gültige unterstützte Kuyena-Sicherung. Deine bisherigen Daten bleiben erhalten.',
      );
    } on PeriodDataException {
      throw const BackupException(
        'Die Periodendaten in der Sicherung sind ungültig oder doppelt.',
      );
    } on JournalDataException {
      throw const BackupException(
        'Die Tageseinträge oder Kalenderkorrekturen in der Sicherung sind ungültig oder doppelt.',
      );
    } on TypeError {
      throw const BackupException('Die Sicherung enthält ungültige Angaben.');
    } on ArgumentError {
      throw const BackupException('Die Sicherung enthält ungültige Angaben.');
    }
  }
}
