import 'package:flutter_test/flutter_test.dart';
import 'package:kuyena_tracker/journal/application/day_journal.dart';
import 'package:kuyena_tracker/journal/data/local_journal_repository.dart';
import 'package:kuyena_tracker/journal/domain/day_entry.dart';
import 'package:kuyena_tracker/periods/application/period_diary.dart';
import 'package:kuyena_tracker/periods/application/period_quick_actions.dart';
import 'package:kuyena_tracker/periods/data/local_period_repository.dart';
import 'package:kuyena_tracker/periods/domain/calendar_date.dart';
import '../support/memory_period_storage.dart';

void main() {
  final today = CalendarDate(2026, 10, 29);
  CalendarDate day(int d) => CalendarDate(2026, 10, d);
  late MemoryPeriodStorage periods, days;
  late PeriodDiary diary;
  late DayJournal journal;
  late PeriodQuickActions actions;
  setUp(() {
    periods = MemoryPeriodStorage();
    days = MemoryPeriodStorage();
    diary = PeriodDiary(
      repository: LocalPeriodRepository(periods),
      clock: () => today.value,
    );
    journal = DayJournal(
      repository: LocalJournalRepository(days),
      clock: () => today.value,
    );
    actions = PeriodQuickActions(diary: diary, journal: journal);
  });

  test('start and inclusive end persist independently of wellbeing', () async {
    await journal.saveWellbeing(
      DayEntry(date: today, symptoms: {Symptom.fatigue}, energy: 0),
    );
    final before = days.value;
    await actions.start(day(25));
    final target = (await actions.overview(today)).period!;
    expect(target.isOngoing, isTrue);
    await actions.finish(target, day(28));
    final reloaded = (await diary.load()).single;
    expect(reloaded.start, day(25));
    expect(reloaded.end, day(28));
    expect(reloaded.isOngoing, isFalse);
    expect((await actions.overview(day(28))).isPeriod, isTrue);
    expect((await actions.overview(today)).isPeriod, isFalse);
    expect(days.value, before);
  });

  test(
    'a legacy log period can be ended once without duplicate starts or data loss',
    () async {
      await journal.save(
        DayEntry(
          date: day(25),
          flow: FlowIntensity.light,
          symptoms: {Symptom.cramps},
        ),
      );
      final before = days.value;
      final target = (await actions.overview(today)).period!;
      await actions.finish(target, day(28));
      expect((await diary.load()).single.end, day(28));
      expect((await actions.overview(day(27))).dayNumber, 3);
      expect((await actions.overview(today)).isPeriod, isFalse);
      expect(days.value, before);
      await expectLater(
        actions.finish(target, day(28)),
        throwsA(isA<PeriodRuleException>()),
      );
      expect((await diary.load()).length, 1);
    },
  );

  test(
    'unknown ends can be completed without assuming ongoing bleeding',
    () async {
      await diary.add(day(25));
      final target = (await actions.overview(today)).period!;
      expect(target.isOngoing, isFalse);
      await actions.finish(target, day(27));
      expect((await diary.load()).single.end, day(27));
    },
  );

  test(
    'ongoing, duplicate and overlapping starts are rejected unchanged',
    () async {
      await actions.start(day(25));
      final before = periods.value;
      await expectLater(
        actions.start(day(27)),
        throwsA(isA<PeriodRuleException>()),
      );
      expect(periods.value, before);
      final target = (await diary.load()).single;
      await actions.finish(target, day(27));
      final completed = periods.value;
      await expectLater(
        actions.start(day(26)),
        throwsA(isA<PeriodRuleException>()),
      );
      expect(periods.value, completed);
    },
  );

  test(
    'future starts and ends before start or after today never write',
    () async {
      await expectLater(
        actions.start(day(30)),
        throwsA(isA<PeriodRuleException>()),
      );
      expect(periods.value, isNull);
      await actions.start(day(25));
      final target = (await diary.load()).single;
      final before = periods.value;
      await expectLater(
        actions.finish(target, day(24)),
        throwsA(isA<PeriodRuleException>()),
      );
      await expectLater(
        actions.finish(target, day(30)),
        throwsA(isA<PeriodRuleException>()),
      );
      expect(periods.value, before);
    },
  );

  test(
    'conflicting stored absence or later bleeding must be corrected explicitly',
    () async {
      await journal.setFlow(day(25), FlowIntensity.none);
      await expectLater(
        actions.start(day(25)),
        throwsA(isA<PeriodRuleException>()),
      );
      expect(periods.value, isNull);
      await journal.setFlow(day(25), FlowIntensity.light);
      await journal.setFlow(day(28), FlowIntensity.medium);
      final target = (await actions.overview(today)).period!;
      await expectLater(
        actions.finish(target, day(27)),
        throwsA(isA<PeriodRuleException>()),
      );
      expect(periods.value, isNull);
    },
  );

  test('failed source reads and writes never claim a saved period', () async {
    days.failRead = true;
    await expectLater(actions.start(day(25)), throwsStateError);
    expect(periods.value, isNull);
    days.failRead = false;
    periods.failWrite = true;
    await expectLater(actions.start(day(25)), throwsStateError);
    expect(periods.value, isNull);
    periods.failWrite = false;
    await actions.start(day(25));
    expect((await diary.load()).single.isOngoing, isTrue);
  });

  test(
    'a stale end action cannot overwrite a period already completed elsewhere',
    () async {
      await actions.start(day(25));
      final target = (await diary.load()).single;
      await diary.correct(target.id, target.start, end: day(27));
      final before = periods.value;
      await expectLater(
        actions.finish(target, day(28)),
        throwsA(isA<PeriodRuleException>()),
      );
      expect(periods.value, before);
    },
  );

  test('queued quick starts cannot create two ongoing periods', () async {
    final first = actions.start(day(25));
    final second = actions.start(day(26));
    await expectLater(second, throwsA(isA<PeriodRuleException>()));
    await first;
    expect((await diary.load()).length, 1);
  });
  test(
    'backfilled period requires an end before a later ongoing period and preserves it',
    () async {
      await actions.start(day(25));
      final recent = (await diary.load()).single;
      final before = periods.value;
      expect((await actions.prepare(day(10))).nextStart, day(25));
      await expectLater(
        actions.start(day(10)),
        throwsA(isA<PeriodRuleException>()),
      );
      expect(periods.value, before);
      await actions.start(day(10), end: day(15));
      final saved = await diary.load();
      expect(saved.length, 2);
      expect(saved.first.id, recent.id);
      expect(saved.first.isOngoing, isTrue);
      expect(saved.last.start, day(10));
      expect(saved.last.end, day(15));
      expect(saved.last.isOngoing, isFalse);
      expect((await actions.overview(today)).dayNumber, 5);
    },
  );

  test(
    'a closed period can be inserted between two documented periods',
    () async {
      await diary.add(day(1), end: day(5));
      await diary.add(day(25), end: day(28));
      final originalIds = (await diary.load()).map((p) => p.id).toSet();
      await expectLater(
        actions.start(day(10)),
        throwsA(isA<PeriodRuleException>()),
      );
      await actions.start(day(10), end: day(15));
      final saved = await diary.load();
      expect(saved.length, 3);
      expect(saved.where((p) => originalIds.contains(p.id)).length, 2);
      expect(saved[1].start, day(10));
      expect(saved[1].end, day(15));
      expect((await actions.overview(day(15))).isPeriod, isTrue);
      expect((await actions.overview(day(16))).isPeriod, isFalse);
    },
  );

  test(
    'an end before the next start is allowed; touching or overlapping ranges are rejected',
    () async {
      await diary.add(day(1), end: day(5));
      await diary.add(day(25), isOngoing: true);
      final before = periods.value;
      for (final span in [(4, 10), (10, 25), (10, 26)]) {
        await expectLater(
          actions.start(day(span.$1), end: day(span.$2)),
          throwsA(isA<PeriodRuleException>()),
        );
        expect(periods.value, before);
      }
      await actions.start(day(6), end: day(24));
      expect((await diary.load())[1].end, day(24));
    },
  );

  test(
    'a past period may be saved with an end even without a later start',
    () async {
      await actions.start(day(10), end: day(15));
      final saved = (await diary.load()).single;
      expect(saved.isOngoing, isFalse);
      expect(saved.end, day(15));
      expect((await actions.prepare(day(20))).nextStart, isNull);
      expect((await actions.overview(today)).isPeriod, isFalse);
    },
  );

  test(
    'backfilling does not invent the end of an older unknown period',
    () async {
      await diary.add(day(1));
      await diary.add(day(25), isOngoing: true);
      await actions.start(day(10), end: day(15));
      final saved = await diary.load();
      expect(saved.last.start, day(1));
      expect(saved.last.end, isNull);
      expect(saved.last.isOngoing, isFalse);
      expect(saved.first.isOngoing, isTrue);
    },
  );

  test(
    'absence inside the requested span is not silently overwritten',
    () async {
      await journal.setFlow(day(12), FlowIntensity.none);
      final before = days.value;
      await expectLater(
        actions.start(day(10), end: day(15)),
        throwsA(isA<PeriodRuleException>()),
      );
      expect(periods.value, isNull);
      expect(days.value, before);
    },
  );

  test(
    'saving rechecks a later start added after the form was opened',
    () async {
      expect((await actions.prepare(day(10))).nextStart, isNull);
      await diary.add(day(25), isOngoing: true);
      final before = periods.value;
      await expectLater(
        actions.start(day(10)),
        throwsA(isA<PeriodRuleException>()),
      );
      expect(periods.value, before);
    },
  );

  test('invalid optional ends never write a historical period', () async {
    await expectLater(
      actions.start(day(10), end: day(9)),
      throwsA(isA<PeriodRuleException>()),
    );
    await expectLater(
      actions.start(day(10), end: day(30)),
      throwsA(isA<PeriodRuleException>()),
    );
    expect(periods.value, isNull);
  });
}
