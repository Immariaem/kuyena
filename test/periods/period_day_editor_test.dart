import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuyena_tracker/journal/application/day_journal.dart';
import 'package:kuyena_tracker/journal/data/local_journal_repository.dart';
import 'package:kuyena_tracker/journal/domain/day_entry.dart';
import 'package:kuyena_tracker/periods/application/period_day_editor.dart';
import 'package:kuyena_tracker/periods/application/period_diary.dart';
import 'package:kuyena_tracker/periods/application/period_quick_actions.dart';
import 'package:kuyena_tracker/periods/application/period_timeline.dart';
import 'package:kuyena_tracker/periods/data/local_period_repository.dart';
import 'package:kuyena_tracker/periods/domain/calendar_date.dart';
import 'package:kuyena_tracker/periods/domain/period.dart';
import 'package:kuyena_tracker/periods/domain/period_day_overview.dart';
import '../support/memory_period_storage.dart';

CalendarDate d(int day) => CalendarDate(2026, 10, day);

class CountingStorage extends MemoryPeriodStorage {
  int writes = 0;
  @override
  Future<void> write(String value) async {
    writes++;
    await super.write(value);
  }
}

void main() {
  late MemoryPeriodStorage manual;
  late CountingStorage days;
  late DayJournal journal;
  late PeriodDiary diary;
  late PeriodDayEditor editor;
  setUp(() {
    manual = MemoryPeriodStorage();
    days = CountingStorage();
    diary = PeriodDiary(
      repository: LocalPeriodRepository(manual),
      clock: () => d(29).value,
    );
    journal = DayJournal(
      repository: LocalJournalRepository(days),
      clock: () => d(29).value,
    );
    editor = PeriodDayEditor(diary: diary, journal: journal);
  });
  Future<void> seed({bool ongoing = false}) =>
      LocalPeriodRepository(manual).save([
        Period(
          id: 'original',
          start: d(25),
          end: ongoing ? null : d(29),
          isOngoing: ongoing,
        ),
      ]);
  Future<void> mark(Map<CalendarDate, bool> changes) async =>
      editor.save(await editor.load(), changes);

  test(
    'calendar-only adjacent days form one completed period, no default prediction',
    () async {
      await mark({d(26): true, d(27): true, d(28): true});
      final data = await editor.load(),
          p = (await editor.load()).timeline.periods.single;
      expect(p.start, d(26));
      expect(p.end, d(28));
      expect(p.isOngoing, isFalse);
      expect(data.contains(d(29)), isFalse);
      expect(data.timeline.calendarPeriodIds, {p.id});
      expect(
        PeriodDayOverview.fromPeriods(data.timeline.periods, d(29)).estimate,
        isNull,
      );
      expect(manual.value, isNull);
    },
  );
  test(
    'removing an interior day keeps one cycle and its identity, not a new cycle',
    () async {
      await seed();
      final id = (await editor.load()).timeline.periods.single.id;
      await mark({d(27): false});
      final data = await editor.load();
      expect(data.timeline.periods.length, 1);
      final p = data.timeline.periods.single;
      expect(p.id, id);
      expect(p.start, d(25));
      expect(p.end, d(29));
      expect(p.documentedDayCount, 4);
      expect(data.contains(d(27)), isFalse);
      expect(data.contains(d(28)), isTrue);
      expect(
        PeriodDayOverview.fromPeriods(data.timeline.periods, d(27)).isPeriod,
        isFalse,
      );
    },
  );
  test(
    'removing first and last corrects visible bounds and preserves raw records',
    () async {
      await seed();
      final raw = manual.value;
      await mark({d(25): false, d(29): false});
      final p = (await editor.load()).timeline.periods.single;
      expect(p.start, d(26));
      expect(p.end, d(28));
      expect(manual.value, raw);
    },
  );
  test(
    'all days removed stays removed tomorrow for completed and ongoing periods',
    () async {
      for (final ongoing in [false, true]) {
        await journal.clear();
        await seed(ongoing: ongoing);
        await mark({for (var i = 25; i <= 29; i++) d(i): false});
        expect((await editor.load()).timeline.periods, isEmpty);
        final projected = PeriodTimeline.from(
          periods: await diary.load(),
          entries: [],
          periodDays: (await journal.load()).periodDays,
          asOf: d(30),
        );
        expect(projected.periods, isEmpty);
      }
    },
  );
  test(
    'ongoing interior removal preserves later days; removing tail ends at last selected day',
    () async {
      await seed(ongoing: true);
      await mark({d(26): false});
      var data = await editor.load();
      expect(data.contains(d(28)), isTrue);
      expect(data.contains(d(29)), isTrue);
      expect(data.timeline.periods.single.isOngoing, isTrue);
      await mark({d(28): false, d(29): false});
      data = await editor.load();
      expect(data.timeline.periods.single.end, d(27));
      expect(data.contains(d(28)), isFalse);
      final next = PeriodTimeline.from(
        periods: await diary.load(),
        entries: [],
        periodDays: data.journal.periodDays,
        asOf: d(30),
      );
      expect(next.periods.single.isOngoing, isFalse);
      expect(next.periods.single.end, d(27));
    },
  );
  test(
    'calendar-only interior removal retains one period; restore repairs the gap',
    () async {
      await mark({d(25): true, d(26): true, d(27): true});
      await mark({d(26): false});
      var data = await editor.load();
      expect(data.timeline.periods.length, 1);
      expect(data.contains(d(26)), isFalse);
      expect(data.timeline.periods.single.documentedDayCount, 2);
      await mark({d(26): true});
      data = await editor.load();
      expect(data.timeline.periods.length, 1);
      expect(data.contains(d(26)), isTrue);
      expect(data.timeline.periods.single.documentedDayCount, 3);
    },
  );
  test(
    'extending and bridging selected dates merges adjacent ranges using the manual identity',
    () async {
      await LocalPeriodRepository(manual).save([
        Period(id: 'kept', start: d(25), end: d(26)),
        Period(id: 'other', start: d(28), end: d(29)),
      ]);
      await mark({d(24): true, d(27): true});
      final data = await editor.load();
      expect(data.timeline.periods.length, 1);
      expect(data.timeline.periods.single.id, 'kept');
      expect(data.timeline.periods.single.start, d(24));
      expect(data.timeline.periods.single.end, d(29));
    },
  );
  test(
    'legacy bleeding can be unmarked without deleting symptoms or raw flow',
    () async {
      await journal.save(
        DayEntry(
          date: d(27),
          flow: FlowIntensity.light,
          symptoms: {Symptom.cramps},
          note: 'Keep',
          energy: 0,
        ),
      );
      await journal.setReminders(true);
      final entry = (await journal.load()).entryFor(d(27))!.toJson();
      final writes = days.writes;
      await mark({d(27): false, d(28): false, d(29): false});
      final data = await editor.load();
      expect(data.timeline.periods, isEmpty);
      expect(data.journal.entryFor(d(27))!.toJson(), entry);
      expect(data.journal.reminders, isTrue);
      expect(days.writes, writes + 1);
    },
  );
  test(
    'calendar selection overrides legacy None on that date without changing the observation',
    () async {
      await seed();
      await journal.setFlow(d(28), FlowIntensity.none);
      await mark({d(28): true});
      final data = await editor.load();
      expect(data.contains(d(28)), isTrue);
      expect(data.timeline.periods.single.end, d(28));
      expect(data.journal.entryFor(d(28))!.flow, FlowIntensity.none);
    },
  );
  test(
    'wellbeing changes during a draft are preserved and do not invalidate period selection',
    () async {
      final draft = await editor.load();
      await journal.saveWellbeing(
        DayEntry(date: d(27), symptoms: {Symptom.fatigue}, note: 'new'),
      );
      await journal.setReminders(true);
      await editor.save(draft, {d(27): true});
      final data = await journal.load();
      expect(data.entryFor(d(27))!.note, 'new');
      expect(data.reminders, isTrue);
      expect(data.periodDays[d(27)], isTrue);
    },
  );
  test(
    'stale manual dates, legacy flow or calendar corrections block a pending draft',
    () async {
      var draft = await editor.load();
      await seed();
      await expectLater(
        editor.save(draft, {d(20): true}),
        throwsA(isA<PeriodRuleException>()),
      );
      draft = await editor.load();
      await journal.setFlow(d(28), FlowIntensity.none);
      await expectLater(
        editor.save(draft, {d(20): true}),
        throwsA(isA<PeriodRuleException>()),
      );
      draft = await editor.load();
      await mark({d(25): false});
      final before = days.value;
      await expectLater(
        editor.save(draft, {d(20): true}),
        throwsA(isA<PeriodRuleException>()),
      );
      expect(days.value, before);
    },
  );
  test(
    'write failure and future date leave saved values unchanged; an empty save writes nothing',
    () async {
      await mark({d(25): true});
      final before = days.value,
          draft = await editor.load(),
          writes = days.writes;
      await editor.save(draft, {});
      expect(days.writes, writes);
      await expectLater(
        editor.save(draft, {d(30): true}),
        throwsA(isA<PeriodRuleException>()),
      );
      days.failWrite = true;
      await expectLater(editor.save(draft, {d(26): true}), throwsStateError);
      expect(days.value, before);
    },
  );
  test(
    'version one migrates only on save and all journal actions preserve corrections',
    () async {
      days.value = jsonEncode({
        'version': 1,
        'entries': [DayEntry(date: d(25), note: 'Old').toJson()],
        'reminders': true,
      });
      final old = days.value;
      expect((await journal.load()).periodDays, isEmpty);
      expect(days.value, old);
      await mark({d(25): true, d(26): false});
      expect(jsonDecode(days.value!)['version'], 2);
      await journal.saveWellbeing(DayEntry(date: d(25), note: 'Updated'));
      await journal.setFlow(d(25), FlowIntensity.heavy);
      await journal.removeWellbeing(d(25));
      await journal.setReminders(false);
      await journal.remove(d(25));
      await journal.save(DayEntry(date: d(24), note: 'Other'));
      expect((await journal.load()).periodDays, {d(25): true, d(26): false});
      await journal.clear();
      expect(days.value, isNull);
      expect((await journal.load()).periodDays, isEmpty);
    },
  );
  test(
    'invalid or duplicate corrections are rejected without overwriting storage',
    () async {
      for (final values in [
        null,
        [
          {'date': '2026-02-30', 'period': true},
        ],
        [
          {'date': '2026-10-25', 'period': 'yes'},
        ],
        [
          {'date': '2026-10-25', 'period': true},
          {'date': '2026-10-25', 'period': false},
        ],
      ]) {
        days.value = jsonEncode({
          'version': 2,
          'entries': [],
          'reminders': false,
          'periodDays': values,
        });
        final before = days.value;
        await expectLater(journal.load(), throwsA(isA<JournalDataException>()));
        await expectLater(
          journal.saveWellbeing(DayEntry(date: d(25), note: 'Draft')),
          throwsA(isA<JournalDataException>()),
        );
        expect(days.value, before);
      }
    },
  );
  test(
    'calendar corrections are immutable and stale low-level updates cannot overwrite them',
    () async {
      await mark({d(25): true});
      final data = await journal.load();
      expect(() => data.periodDays[d(25)] = false, throwsUnsupportedError);
      await expectLater(
        journal.updatePeriodDays({d(26): true}, expected: {}),
        throwsStateError,
      );
      expect((await journal.load()).periodDays, {d(25): true});
    },
  );
  test(
    'month and year boundaries form adjacent periods and future corrections are not displayed',
    () {
      final dec31 = CalendarDate(2025, 12, 31),
          jan1 = CalendarDate(2026, 1, 1),
          future = d(30);
      final data = PeriodDaySnapshot(
        manual: [],
        journal: JournalData(
          periodDays: {dec31: true, jan1: true, future: true},
        ),
        today: d(29),
      );
      expect(data.timeline.periods.single.start, dec31);
      expect(data.timeline.periods.single.end, jan1);
      expect(data.contains(future), isFalse);
    },
  );
  test(
    'quick actions do not silently undo removed calendar days or ignore later marked days',
    () async {
      await seed(ongoing: true);
      await mark({d(26): false});
      final quick = PeriodQuickActions(diary: diary, journal: journal),
          period = (await editor.load()).timeline.periods.single;
      await expectLater(
        quick.finish(period, d(27)),
        throwsA(isA<PeriodRuleException>()),
      );
      await mark({for (var i = 25; i <= 29; i++) d(i): false});
      await expectLater(
        quick.start(d(25), end: d(29)),
        throwsA(isA<PeriodRuleException>()),
      );
    },
  );
}
