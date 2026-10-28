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
