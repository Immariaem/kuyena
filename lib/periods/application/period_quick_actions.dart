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
    final result = _pending.then((_) => operation());
    _pending = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }

  Future<void> start(CalendarDate date) => _run(() => _start(date));
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
        asOf: diary.today,
      ),
    );
  }

  Future<PeriodDayOverview> overview(CalendarDate date) async {
    final data = await _load();
    return PeriodDayOverview.fromPeriods(
      data.timeline.periods,
      date,
      asOf: diary.today,
      bleedingAbsent: data.days.entryFor(date)?.flow == FlowIntensity.none,
    );
  }

  Future<void> _start(CalendarDate date) async {
    final data = await _load();
    if (data.timeline.periods.any((p) => p.isOngoing)) {
      throw const PeriodRuleException(
        'Es läuft bereits eine Periode. Beende sie zuerst oder prüfe deinen Verlauf.',
      );
    }
    if (data.timeline.periods.any(
      (p) =>
          p.start.compareTo(date) >= 0 ||
          (p.end != null && p.end!.compareTo(date) >= 0),
    )) {
      throw const PeriodRuleException(
        'Für diesen Zeitraum sind bereits Periodenangaben vorhanden. Bitte prüfe den Verlauf.',
      );
    }
    if (data.days.entryFor(date)?.flow == FlowIntensity.none) {
      throw const PeriodRuleException(
        'Für diesen Tag ist keine Blutung eingetragen. Du kannst diese Blutungsangabe im Periodenverlauf korrigieren.',
      );
    }
    await diary.add(date, isOngoing: true);
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
                  e.flow != FlowIntensity.none,
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
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
