import '../../periods/domain/calendar_date.dart';
import '../data/local_journal_repository.dart';
import '../domain/day_entry.dart';

final class DayJournal {
  DayJournal({required this.repository, DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final LocalJournalRepository repository;
  final DateTime Function() clock;
  CalendarDate get today => CalendarDate.fromDateTime(clock());
  Future<void> _pending = Future.value();
  Future<T> _run<T>(Future<T> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object e, StackTrace s) {});
    return result;
  }

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
        entries: [...current.entries.where((e) => e.date != entry.date), entry]
          ..sort((a, b) => b.date.compareTo(a.date)),
      ),
    );
  });

  /// Edits only wellbeing; legacy bleeding observations are merged from storage.
  Future<void> saveWellbeing(DayEntry entry) => _run(() async {
    if (entry.date.compareTo(today) > 0 || !entry.hasWellbeing) {
      throw ArgumentError('Add wellbeing for today or an earlier date.');
    }
    final current = await repository.load();
    final previous = current.entryFor(entry.date);
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

  Future<void> removeWellbeing(CalendarDate date) => _run(() async {
    final current = await repository.load();
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
        entries: current.entries.where((e) => e.date != date).toList(),
      ),
    );
  });
  Future<void> setReminders(bool enabled) => _run(() async {
    final current = await repository.load();
    await repository.save(
      JournalData(entries: current.entries, reminders: enabled),
    );
  });
  Future<void> clear() => _run(repository.clear);
}
