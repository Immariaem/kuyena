import '../../profile/domain/user_profile.dart';
import '../../periods/domain/calendar_date.dart';
import '../../periods/application/period_timeline.dart';
import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import '../../journal/data/local_journal_repository.dart';
import '../../journal/domain/day_entry.dart';
import '../../periods/data/local_period_repository.dart';
import '../../periods/domain/period.dart';
import 'data_lock.dart';

final class LocalDataException implements Exception {
  const LocalDataException(this.message);
  final String message;
}

final class StoredData {
  StoredData({
    required List<Period> periods,
    required this.journal,
    required this.revision,
    this.profile,
  }) : periods = List.unmodifiable(periods);
  final List<Period> periods;
  final JournalData journal;
  final UserProfile? profile;

  /// Opaque content fingerprint. Never displayed or sent anywhere.
  final String revision;
}

/// One verified secure-storage value commits period and journal data together.
/// Legacy keys migrate only after a validated copy has been written and read back.
final class LocalAppStore {
  LocalAppStore({
    required this.storage,
    required this.legacyPeriods,
    required this.legacyJournal,
    required this.lock,
  });
  final PeriodStorage storage, legacyPeriods, legacyJournal;
  final DataLock lock;
  PeriodStorage get periodStorage => _SectionStorage(this, true);
  PeriodStorage get journalStorage => _SectionStorage(this, false);

  Future<String> fingerprint() => lock.run(_fingerprint);
  Future<String> _fingerprint() async {
    final values = await Future.wait([
      storage.read(),
      legacyPeriods.read(),
      legacyJournal.read(),
    ]);
    final hash = await Sha256().hash(utf8.encode(jsonEncode(values)));
    return base64UrlEncode(hash.bytes);
  }

  Future<({String? periods, String? journal, String? profile})> _read() async {
    final raw = await storage.read();
    if (raw != null) {
      final data = _decode(raw);
      await _cleanupLegacy();
      return data;
    }
    final old = await Future.wait([legacyPeriods.read(), legacyJournal.read()]);
    final data = (periods: old[0], journal: old[1], profile: null as String?);
    _validate(data);
    if (old.any((value) => value != null)) await _commit(data);
    return data;
  }

  void _validate(({String? periods, String? journal, String? profile}) data) {
    if (data.periods != null) LocalPeriodRepository.decode(data.periods!);
    if (data.journal != null) LocalJournalRepository.decode(data.journal!);
    if (data.profile != null) UserProfile.decode(data.profile!);
  }

  ({String? periods, String? journal, String? profile}) _decode(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic> ||
          (json['version'] != 1 && json['version'] != 2) ||
          (json['version'] == 2 &&
              (!json.containsKey('profile') ||
                  (json['profile'] != null && json['profile'] is! String))) ||
          json['generation'] is! String ||
          !(RegExp(r'^[a-f0-9]{32}$').hasMatch(json['generation'] as String)) ||
          !json.containsKey('periods') ||
          !json.containsKey('journal') ||
          (json['periods'] != null && json['periods'] is! String) ||
          (json['journal'] != null && json['journal'] is! String)) {
        throw const LocalDataException(
          'Die gespeicherten Daten konnten nicht gelesen werden.',
        );
      }
      final data = (
        periods: json['periods'] as String?,
        journal: json['journal'] as String?,
        profile: json['version'] == 1 ? null : json['profile'] as String?,
      );
      _validate(data);
      return data;
    } on FormatException {
      throw const LocalDataException(
        'Die gespeicherten Daten sind beschädigt.',
      );
    }
  }

  Future<void> _cleanupLegacy() async {
    // Always try both keys. Never delete the current committed value here.
    final results = await Future.wait([
      _eraseIfPresent(legacyPeriods),
      _eraseIfPresent(legacyJournal),
    ]);
    if (results.any((ok) => !ok)) {
      throw const LocalDataException(
        'Die Daten sind übernommen, aber alte Speicherkopien konnten noch nicht bereinigt werden. Bitte versuche es erneut.',
      );
    }
  }

  Future<bool> _eraseIfPresent(PeriodStorage target) async {
    try {
      if (await target.read() != null) await target.delete();
      return await target.read() == null;
    } catch (_) {
      return false;
    }
  }

  Future<void> _commit(
    ({String? periods, String? journal, String? profile}) data,
  ) async {
    _validate(data);
    final random = Random.secure();
    final generation = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final raw = jsonEncode({
      'version': 2,
      'generation': generation,
      'periods': data.periods,
      'journal': data.journal,
      'profile': data.profile,
    });
    await storage.write(raw);
    if (await storage.read() != raw) {
      throw const LocalDataException(
        'Speichern konnte nicht bestätigt werden. Bitte lade die Daten neu.',
      );
    }
    await _cleanupLegacy();
  }

  Future<StoredData> load() => lock.run(() async {
    final data = await _read();
    return StoredData(
      periods: data.periods == null
          ? []
          : LocalPeriodRepository.decode(data.periods!),
      journal: data.journal == null
          ? JournalData()
          : LocalJournalRepository.decode(data.journal!),
      revision: await _fingerprint(),
      profile: data.profile == null ? null : UserProfile.decode(data.profile!),
    );
  });
  Future<void> replace({
    required List<Period> periods,
    required JournalData journal,
    UserProfile? profile,
    required String expectedRevision,
  }) => lock.run(() async {
    if (await _fingerprint() != expectedRevision) {
      throw const LocalDataException(
        'Deine Daten wurden inzwischen geändert. Bitte prüfe die Sicherung erneut, bevor du sie wiederherstellst.',
      );
    }
    await _commit((
      periods: LocalPeriodRepository.encode(periods),
      journal: LocalJournalRepository.encode(journal),
      profile: profile?.encode(),
    ));
  });
  Future<void> clear() => lock.run(() async {
    // An empty commit prevents legacy data from reappearing after a crash or
    // incomplete cleanup. Only format/generation metadata remains, no health data.
    await _commit((periods: null, journal: null, profile: null));
  });

  Future<void> saveProfile(
    UserProfile profile, {
    required UserProfile? expected,
    required CalendarDate today,
  }) => lock.run(() async {
    final current = await _read();
    final previous = current.profile == null
        ? null
        : UserProfile.decode(current.profile!);
    if (previous?.encode() != expected?.encode()) {
      throw const LocalDataException(
        'Deine Einstellungen wurden inzwischen geändert. Öffne die Einrichtung bitte erneut.',
      );
    }
    if (profile.lastPeriodStart != null &&
        profile.lastPeriodStart!.compareTo(today) > 0) {
      throw const LocalDataException(
        'Der Periodenbeginn darf nicht in der Zukunft liegen.',
      );
    }
    if (profile.lastPeriodEnd != null &&
        profile.lastPeriodEnd!.compareTo(today) > 0) {
      throw const LocalDataException(
        'Das Periodenende darf nicht in der Zukunft liegen.',
      );
    }
    var periods = current.periods;
    var journal = current.journal;
    if (profile.completed &&
        previous?.completed != true &&
        profile.lastPeriodStart != null) {
      final start = profile.lastPeriodStart!;
      if (journal != null &&
          LocalJournalRepository.decode(journal).periodDays[start] == false) {
        throw const LocalDataException(
          'Dieser Tag wurde im Kalender als ohne Periode markiert. Bitte prüfe ihn dort oder wähle „Weiß ich nicht“.',
        );
      }
      final original = periods == null
          ? <Period>[]
          : LocalPeriodRepository.decode(periods).toList();
      final observations = journal == null
          ? JournalData()
          : LocalJournalRepository.decode(journal);
      final timeline = PeriodTimeline.from(
        periods: original,
        entries: observations.entries,
        periodDays: observations.periodDays,
        asOf: today,
      );
      final end = profile.lastPeriodEnd;
      final last = end ?? (profile.lastPeriodOngoing ? today : start);
      final matching = timeline.periods.where((p) => p.start == start).toList();
      if (matching.length > 1) {
        throw const LocalDataException(
          'Mehrere Perioden haben diesen Beginn. Bitte prüfe den Verlauf im Kalender.',
        );
      }
      final others = timeline.periods.where((p) => p.start != start);
      if (others.any(
        (p) =>
            p.start.compareTo(last) <= 0 &&
            (p.end ?? (p.isOngoing ? today : p.start)).compareTo(start) >= 0,
      )) {
        throw const LocalDataException(
          'Dieser Zeitraum überschneidet sich mit einer vorhandenen Periode. Bitte prüfe die Einträge im Kalender.',
        );
      }
      if (observations.periodDays.entries.any(
        (e) =>
            !e.value &&
            e.key.compareTo(start) >= 0 &&
            e.key.compareTo(last) <= 0,
      )) {
        throw const LocalDataException(
          'In diesem Zeitraum wurden Tage als ohne Periode markiert. Bitte prüfe sie im Kalender.',
        );
      }
      if (matching.isEmpty) {
        original.add(
          Period(
            id: 'onboarding-${start.iso}',
            start: start,
            end: end,
            isOngoing: profile.lastPeriodOngoing,
          ),
        );
      } else if (end != null || profile.lastPeriodOngoing) {
        final index = original.indexWhere((p) => p.id == matching.single.id);
        final existing = matching.single;
        if (existing.end != end ||
            existing.isOngoing != profile.lastPeriodOngoing) {
          if (index < 0 ||
              existing.end != null ||
              existing.isOngoing ||
              existing.excludedDays.isNotEmpty) {
            throw const LocalDataException(
              'Für diesen Beginn gibt es bereits andere Angaben. Bitte ändere den Zeitraum im Kalender.',
            );
          }
          original[index] = Period(
            id: existing.id,
            start: start,
            end: end,
            isOngoing: profile.lastPeriodOngoing,
          );
        }
      }
      if (original.map((p) => p.id).toSet().length != original.length) {
        throw const LocalDataException(
          'Dieser Beginn wurde bereits erfasst. Bitte prüfe den Kalender.',
        );
      }
      periods = LocalPeriodRepository.encode(original);
    }

    if (profile.completed) {
      final oldJournal = journal == null
          ? JournalData()
          : LocalJournalRepository.decode(journal);
      journal = LocalJournalRepository.encode(
        JournalData(
          entries: oldJournal.entries,
          periodDays: oldJournal.periodDays,
          reminders: profile.dailyReminder == true,
        ),
      );
    }
    await _commit((
      periods: periods,
      journal: journal,
      profile: profile.encode(),
    ));
  });

  Future<String?> _readSection(bool periods) => lock.run(() async {
    final data = await _read();
    return periods ? data.periods : data.journal;
  });
  Future<void> _writeSection(bool periods, String? raw) => lock.run(() async {
    final current = await _read();
    await _commit((
      periods: periods ? raw : current.periods,
      journal: periods ? current.journal : raw,
      profile: current.profile,
    ));
  });
}

final class _SectionStorage implements PeriodStorage {
  _SectionStorage(this.store, this.periods);
  final LocalAppStore store;
  final bool periods;
  @override
  Future<String?> read() => store._readSection(periods);
  @override
  Future<void> write(String value) => store._writeSection(periods, value);
  @override
  Future<void> delete() => store._writeSection(periods, null);
}
