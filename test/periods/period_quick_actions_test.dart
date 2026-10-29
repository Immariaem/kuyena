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
}
