import '../../journal/application/day_journal.dart';
import '../../journal/domain/day_entry.dart';
import '../domain/calendar_date.dart';
import '../domain/period.dart';
import '../domain/period_day_overview.dart';
import 'period_diary.dart';
import 'period_timeline.dart';

/// Starts and ends periods without editing daily wellbeing or inventing flow.
final class PeriodQuickActions {
  PeriodQuickActions({required this.diary, this.journal});
  final PeriodDiary diary;
  final DayJournal? journal;
  Future<void> _pending = Future.value();
  Future<void> _run(Future<void> Function() operation) {
    final result = _pending.then((_) => diary.synchronized(operation));
    _pending = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }

  Future<void> start(CalendarDate date, {CalendarDate? end}) =>
      _run(() => _start(date, end: end));
  Future<void> finish(Period period, CalendarDate lastDay) =>
      _run(() => _finish(period, lastDay));

  Future<({List<Period> manual, PeriodTimeline timeline, JournalData days})>
  _load() async {
    final values = await Future.wait<Object>([
      diary.load(),
      journal?.load() ?? Future.value(JournalData()),
    ]);
    final manual = values[0] as List<Period>;
    final days = values[1] as JournalData;
    return (
      manual: manual,
      days: days,
      timeline: PeriodTimeline.from(
        periods: manual,
        entries: days.entries,
        periodDays: days.periodDays,
        asOf: diary.today,
      ),
    );
  }

  Future<({PeriodDayOverview day, CalendarDate? nextStart})> prepare(
    CalendarDate date,
  ) async {
    final data = await _load();
    final laterStarts =
        data.timeline.periods
            .where((p) => p.start.compareTo(date) > 0)
            .map((p) => p.start)
            .toList()
          ..sort();
    return (
      day: PeriodDayOverview.fromPeriods(
        data.timeline.periods,
        date,
        asOf: diary.today,
        bleedingAbsent:
            data.days.periodDays[date] == false ||
            (data.days.periodDays[date] == null &&
                data.days.entryFor(date)?.flow == FlowIntensity.none),
      ),
      nextStart: laterStarts.isEmpty ? null : laterStarts.first,
    );
  }

  Future<PeriodDayOverview> overview(CalendarDate date) async =>
      (await prepare(date)).day;

  Future<void> _start(CalendarDate date, {CalendarDate? end}) async {
    final data = await _load();
    if (date.compareTo(diary.today) > 0 ||
        (end != null &&
            (end.compareTo(date) < 0 || end.compareTo(diary.today) > 0))) {
      throw const PeriodRuleException(
        'Beginn und Ende müssen spätestens heute liegen. Das Ende darf nicht vor dem Beginn liegen.',
      );
    }
    if (data.manual.any((p) => p.start == date) &&
        !data.timeline.periods.any((p) => p.start == date)) {
      throw const PeriodRuleException(
        'Für diesen Beginn gibt es bereits einen korrigierten Eintrag. Du kannst die Tage im Kalender wieder markieren.',
      );
    }
    if (data.timeline.periods.any((p) => p.start == date)) {
      throw const PeriodRuleException(
        'Für diesen Beginn besteht bereits eine Periode. Du kannst sie im Kalender öffnen.',
      );
    }
    final later =
        data.timeline.periods
            .where((p) => p.start.compareTo(date) > 0)
            .map((p) => p.start)
            .toList()
          ..sort();
    final nextStart = later.isEmpty ? null : later.first;
    if (nextStart != null && end == null) {
      throw PeriodRuleException(
        'Am ${nextStart.display} beginnt bereits eine weitere Periode. Bitte gib den letzten Blutungstag der nachgetragenen Periode an.',
      );
    }
    if (nextStart != null && end!.compareTo(nextStart) >= 0) {
      throw PeriodRuleException(
        'Das Ende muss vor dem nächsten Periodenbeginn am ${nextStart.display} liegen.',
      );
    }
    final last = end ?? diary.today;
    for (final existing in data.timeline.periods) {
      // An unknown end confirms only the recorded start; it is not treated as
      // ongoing bleeding and never silently supplied with an invented end.
      final existingLast =
          existing.end ?? (existing.isOngoing ? diary.today : existing.start);
      if (existing.start.compareTo(last) <= 0 &&
          existingLast.compareTo(date) >= 0) {
        throw PeriodRuleException(
          'Dieser Zeitraum überschneidet sich mit der Periode ab ${existing.start.display}. Bitte prüfe Beginn und Ende.',
        );
      }
    }
    final absent =
        data.days.entries
            .where(
              (e) =>
                  e.flow == FlowIntensity.none &&
                  data.days.periodDays[e.date] != true &&
                  e.date.compareTo(date) >= 0 &&
                  e.date.compareTo(last) <= 0,
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    if (absent.isNotEmpty) {
      throw PeriodRuleException(
        'Am ${absent.first.date.display} ist keine Blutung eingetragen. Bitte prüfe den Zeitraum oder korrigiere diese Blutungsangabe im Kalender.',
      );
    }
    if (data.days.periodDays.entries.any(
      (e) =>
          !e.value && e.key.compareTo(date) >= 0 && e.key.compareTo(last) <= 0,
    )) {
      throw const PeriodRuleException(
        'In diesem Zeitraum wurden Periodentage entfernt. Markiere sie bei Bedarf im Kalender erneut.',
      );
    }
    await diary.add(date, end: end, isOngoing: end == null);
  }

  Future<void> _finish(Period expected, CalendarDate lastDay) async {
    final data = await _load();
    final matching = data.timeline.periods.where((p) => p.id == expected.id);
    if (matching.isEmpty ||
        matching.single.start != expected.start ||
        matching.single.end != null) {
      throw const PeriodRuleException(
        'Diese Periode wurde inzwischen geändert. Bitte schließe die Eingabe und lade sie neu.',
      );
    }
    final target = matching.single;
    if (lastDay.compareTo(target.start) < 0 ||
        lastDay.compareTo(diary.today) > 0) {
      throw const PeriodRuleException(
        'Der letzte Blutungstag muss zwischen Beginn und heute liegen.',
      );
    }
    if (data.timeline.periods.any(
      (p) =>
          p.id != target.id &&
          p.start.compareTo(target.start) > 0 &&
          p.start.compareTo(lastDay) <= 0,
    )) {
      throw const PeriodRuleException(
        'Das Ende überschneidet sich mit einer anderen Periode. Bitte prüfe den Verlauf.',
      );
    }
    final laterStarts =
        data.timeline.periods
            .where((p) => p.start.compareTo(target.start) > 0)
            .map((p) => p.start)
            .toList()
          ..sort();
    final nextStart = laterStarts.isEmpty ? null : laterStarts.first;
    final laterBleeding =
        data.days.entries
            .where(
              (e) =>
                  e.date.compareTo(lastDay) > 0 &&
                  e.date.compareTo(diary.today) <= 0 &&
                  e.date.compareTo(target.start) >= 0 &&
                  (nextStart == null || e.date.compareTo(nextStart) < 0) &&
                  e.flow != null &&
                  e.flow != FlowIntensity.none &&
                  data.days.periodDays[e.date] != false,
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final laterMarked =
        data.days.periodDays.entries
            .where(
              (e) =>
                  e.value &&
                  e.key.compareTo(lastDay) > 0 &&
                  e.key.compareTo(diary.today) <= 0 &&
                  (nextStart == null || e.key.compareTo(nextStart) < 0),
            )
            .map((e) => e.key)
            .toList()
          ..sort();
    if (laterMarked.isNotEmpty) {
      throw PeriodRuleException(
        'Am ${laterMarked.first.display} ist danach noch ein Periodentag markiert. Bitte prüfe deine Auswahl im Kalender.',
      );
    }
    if (laterBleeding.isNotEmpty) {
      throw PeriodRuleException(
        'Am ${laterBleeding.first.date.display} ist danach noch Blutung eingetragen. Wähle ein passendes Ende oder korrigiere die Blutungsangabe im Verlauf.',
      );
    }
    if (data.timeline.logPeriodIds.contains(target.id)) {
      // Explicit confirmation materializes this existing start once. Old Log
      // observations remain untouched and reconcile with this completed range.
      await diary.add(target.start, end: lastDay);
    } else {
      await diary.correct(
        target.id,
        target.start,
        end: lastDay,
        isOngoing: false,
      );
    }
  }
}
