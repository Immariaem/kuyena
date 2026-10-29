import 'dart:convert';
import '../../data/storage/data_lock.dart';
import '../../periods/domain/calendar_date.dart';
import '../data/local_journal_repository.dart';
import '../domain/day_entry.dart';

final class JournalConflictException implements Exception {
  const JournalConflictException();
  String get message =>
      'Dieser Tageseintrag wurde inzwischen geändert. Schließe die Eingabe und öffne den Tag erneut, bevor du speicherst.';
}

final class DayJournal {
  DayJournal({
    required this.repository,
    DateTime Function()? clock,
    DataLock? dataLock,
  }) : dataLock = dataLock ?? DataLock(),
       clock = clock ?? DateTime.now;
  final LocalJournalRepository repository;
  final DateTime Function() clock;
  CalendarDate get today => CalendarDate.fromDateTime(clock());
  final DataLock dataLock;
  Future<T> _run<T>(Future<T> Function() operation) => dataLock.run(operation);

  Future<JournalData> load() => _run(repository.load);
  Future<void> save(DayEntry entry) => _run(() async {
    if (entry.date.compareTo(today) > 0) {
      throw ArgumentError('Choose today or an earlier date.');
    }
    if (entry.isEmpty) throw ArgumentError('Add at least one observation.');
    final current = await repository.load();
    await repository.save(
      JournalData(
        reminders: current.reminders,
        periodDays: current.periodDays,
        entries: [...current.entries.where((e) => e.date != entry.date), entry]
          ..sort((a, b) => b.date.compareTo(a.date)),
      ),
    );
  });

  /// Edits only wellbeing; legacy bleeding observations are merged from storage.
  Future<void> saveWellbeing(
    DayEntry entry, {
    DayEntry? expected,
    bool checkExpected = false,
  }) => _run(() async {
    if (entry.date.compareTo(today) > 0 || !entry.hasWellbeing) {
      throw ArgumentError('Add wellbeing for today or an earlier date.');
    }
    final current = await repository.load();
    final previous = current.entryFor(entry.date);
    if (checkExpected && _wellbeing(previous) != _wellbeing(expected)) {
      throw const JournalConflictException();
    }
    await _replace(
      current,
      DayEntry(
        date: entry.date,
        flow: previous?.flow,
        symptoms: entry.symptoms,
        mood: entry.mood,
        energy: entry.energy,
        note: entry.note,
      ),
    );
  });

  Future<void> removeWellbeing(
    CalendarDate date, {
    DayEntry? expected,
    bool checkExpected = false,
  }) => _run(() async {
    final current = await repository.load();
    if (checkExpected &&
        _wellbeing(current.entryFor(date)) != _wellbeing(expected)) {
      throw const JournalConflictException();
    }
    await _replace(
      current,
      DayEntry(date: date, flow: current.entryFor(date)?.flow),
    );
  });

  /// Separate editor for bleeding observations already recorded in the Log.
  Future<void> setFlow(CalendarDate date, FlowIntensity? flow) =>
      _run(() async {
        if (date.compareTo(today) > 0) {
          throw ArgumentError('No future observations.');
        }
        final current = await repository.load();
        final previous = current.entryFor(date);
        await _replace(
          current,
          DayEntry(
            date: date,
            flow: flow,
            symptoms: previous?.symptoms ?? {},
            mood: previous?.mood,
            energy: previous?.energy,
            note: previous?.note ?? '',
          ),
        );
      });

  Future<void> _replace(JournalData current, DayEntry entry) => repository.save(
    JournalData(
      reminders: current.reminders,
      periodDays: current.periodDays,
      entries: [
        ...current.entries.where((e) => e.date != entry.date),
        if (!entry.isEmpty) entry,
      ]..sort((a, b) => b.date.compareTo(a.date)),
    ),
  );

  Future<void> remove(CalendarDate date) => _run(() async {
    final current = await repository.load();
    await repository.save(
      JournalData(
        reminders: current.reminders,
        periodDays: current.periodDays,
        entries: current.entries.where((e) => e.date != date).toList(),
      ),
    );
  });
  Future<void> setReminders(bool enabled) => _run(() async {
    final current = await repository.load();
    await repository.save(
      JournalData(
        entries: current.entries,
        reminders: enabled,
        periodDays: current.periodDays,
      ),
    );
  });
  Future<void> updatePeriodDays(
    Map<CalendarDate, bool> changes, {
    required Map<CalendarDate, bool> expected,
  }) => _run(() async {
    if (changes.keys.any((date) => date.compareTo(today) > 0)) {
      throw ArgumentError('Period days cannot be in the future.');
    }
    final current = await repository.load();
    if (current.periodDays.length != expected.length ||
        expected.entries.any((e) => current.periodDays[e.key] != e.value)) {
      throw StateError('Period days have changed. Reload before saving.');
    }
    await repository.save(
      JournalData(
        entries: current.entries,
        reminders: current.reminders,
        periodDays: {...current.periodDays, ...changes},
      ),
    );
  });

  String _wellbeing(DayEntry? entry) => jsonEncode({
    'symptoms': (entry?.symptoms ?? <Symptom>{}).map((s) => s.name).toList()
      ..sort(),
    'mood': entry?.mood?.name,
    'energy': entry?.energy,
    'note': entry?.note ?? '',
  });
  Future<void> clear() => _run(repository.clear);
}
