import 'dart:convert';
import '../../journal/application/day_journal.dart';
import '../../journal/domain/day_entry.dart';
import '../domain/calendar_date.dart';
import '../domain/period.dart';
import 'period_diary.dart';
import 'period_timeline.dart';

final class PeriodDaySnapshot {
  PeriodDaySnapshot({
    required this.manual,
    required this.journal,
    required this.today,
  }) : timeline = PeriodTimeline.from(
         periods: manual,
         entries: journal.entries,
         periodDays: journal.periodDays,
         asOf: today,
       );
  final List<Period> manual;
  final JournalData journal;
  final CalendarDate today;
  final PeriodTimeline timeline;
  bool contains(CalendarDate date) {
    if (date.compareTo(today) > 0) return false;
    final correction = journal.periodDays[date];
    if (correction != null) return correction;
    if (journal.entryFor(date)?.flow == FlowIntensity.none) return false;
    return timeline.periods.any((p) => p.includes(date, asOf: today));
  }

  String get signature => jsonEncode({
    'today': today.iso,
    'periods': [
      for (final p in manual.toList()..sort((a, b) => a.id.compareTo(b.id)))
        [p.id, p.start.iso, p.end?.iso, p.isOngoing],
    ],
    'flow': [
      for (final e
          in journal.entries.where((e) => e.flow != null).toList()
            ..sort((a, b) => a.date.compareTo(b.date)))
        [e.date.iso, e.flow!.name],
    ],
    'days': [
      for (final date in journal.periodDays.keys.toList()..sort())
        [date.iso, journal.periodDays[date]],
    ],
  });
}

/// Saves a calendar selection in one journal write. Raw period records and all
/// wellbeing fields are preserved; the shared timeline applies the corrections.
final class PeriodDayEditor {
  PeriodDayEditor({required this.diary, required this.journal});
  final PeriodDiary diary;
  final DayJournal journal;
  Future<PeriodDaySnapshot> load() => diary.synchronized(_load);
  Future<PeriodDaySnapshot> _load() async {
    final data = await Future.wait<Object>([diary.load(), journal.load()]);
    return PeriodDaySnapshot(
      manual: data[0] as List<Period>,
      journal: data[1] as JournalData,
      today: diary.today,
    );
  }

  Future<void> save(
    PeriodDaySnapshot original,
    Map<CalendarDate, bool> changes,
  ) => diary.synchronized(() => _save(original, changes));
  Future<void> _save(
    PeriodDaySnapshot original,
    Map<CalendarDate, bool> changes,
  ) async {
    if (changes.isEmpty) return;
    if (changes.keys.any((date) => date.compareTo(diary.today) > 0)) {
      throw const PeriodRuleException(
        'Periodentage dürfen nicht in der Zukunft liegen.',
      );
    }
    final current = await load();
    if (current.signature != original.signature) {
      throw const PeriodRuleException(
        'Dein Periodenverlauf wurde inzwischen geändert. Bitte lade ihn neu, bevor du speicherst.',
      );
    }
    final edits = Map<CalendarDate, bool>.from(changes);
    // Keep the still-selected end of an ongoing range explicit when an
    // interior day is removed. Removing its tail instead completes the range.
    for (final period in current.timeline.periods.where((p) => p.isOngoing)) {
      if (!changes.keys.any((d) => period.includes(d, asOf: current.today))) {
        continue;
      }
      var last = current.today;
      bool selected(CalendarDate d) => edits[d] ?? current.contains(d);
      while (!selected(last) && last.compareTo(period.start) > 0) {
        last = last.addDays(-1);
      }
      if (selected(last)) edits[last] = true;
    }
    await journal.updatePeriodDays(edits, expected: current.journal.periodDays);
  }
}
