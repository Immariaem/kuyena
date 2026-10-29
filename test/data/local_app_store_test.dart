import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuyena_tracker/data/storage/data_lock.dart';
import 'package:kuyena_tracker/data/storage/local_app_store.dart';
import 'package:kuyena_tracker/journal/application/day_journal.dart';
import 'package:kuyena_tracker/journal/data/local_journal_repository.dart';
import 'package:kuyena_tracker/journal/domain/day_entry.dart';
import 'package:kuyena_tracker/periods/application/period_diary.dart';
import 'package:kuyena_tracker/periods/application/period_day_editor.dart';
import 'package:kuyena_tracker/periods/application/period_quick_actions.dart';
import 'package:kuyena_tracker/periods/domain/calendar_date.dart';
import 'data_fixture.dart';

void main() {
  late DataFixture f;
  setUp(() => f = DataFixture());
  test(
    'Empty reads leave storage empty and no legacy defaults are written',
    () async {
      final data = await f.store.load();
      expect(data.periods, isEmpty);
      expect(data.journal.entries, isEmpty);
      expect(f.storage.value, isNull);
      expect(f.legacyPeriods.value, isNull);
    },
  );
  test(
    'Both legacy documents migrate intact, then legacy keys are retired',
    () async {
      f.legacyPeriods.value = jsonEncode({
        'version': 1,
        'starts': ['2026-10-10'],
      });
      final entry = DayEntry(
        date: dataToday,
        symptoms: {Symptom.cramps},
        energy: 0,
        note: 'Keep',
      ).toJson();
      f.legacyJournal.value = jsonEncode({
        'version': 1,
        'entries': [entry],
        'reminders': true,
      });
      final data = await f.store.load();
      expect(data.periods.single.start, CalendarDate(2026, 10, 10));
      expect(data.periods.single.end, isNull);
      expect(data.journal.entryFor(dataToday)!.toJson(), entry);
      expect(data.journal.reminders, isTrue);
      expect(f.storage.value, isNotNull);
      expect(f.legacyPeriods.value, isNull);
      expect(f.legacyJournal.value, isNull);
      expect((await f.store.load()).revision, data.revision);
    },
  );
  test(
    'Failed migration write preserves both originals; damaged legacy data is never replaced',
    () async {
      f.legacyPeriods.value = jsonEncode({
        'version': 1,
        'starts': ['2026-10-10'],
      });
      f.legacyJournal.value = jsonEncode({
        'version': 1,
        'entries': [],
        'reminders': false,
      });
      final originals = [f.legacyPeriods.value, f.legacyJournal.value];
      f.storage.failWrite = true;
      await expectLater(f.store.load(), throwsStateError);
      expect([f.legacyPeriods.value, f.legacyJournal.value], originals);
      expect(f.storage.value, isNull);
      f.storage.failWrite = false;
      f.legacyJournal.value = 'broken';
      await expectLater(f.store.load(), throwsA(isA<JournalDataException>()));
      expect(f.storage.value, isNull);
    },
  );
  test(
    'Cleanup interruption keeps verified committed data and retries safely',
    () async {
      f.legacyPeriods.value = jsonEncode({
        'version': 1,
        'starts': ['2026-10-10'],
      });
      f.legacyPeriods.failDelete = true;
      await expectLater(f.store.load(), throwsA(isA<LocalDataException>()));
      expect(f.storage.value, isNotNull);
      expect(f.legacyPeriods.value, isNotNull);
      f.legacyPeriods.failDelete = false;
      expect((await f.store.load()).periods.length, 1);
      expect(f.legacyPeriods.value, isNull);
    },
  );
  test(
    'Independent period and wellbeing writes share one lock and preserve both sections',
    () async {
      await Future.wait([
        f.diary.add(dataToday, isOngoing: true),
        f.journal.saveWellbeing(DayEntry(date: dataToday, note: 'Today')),
        f.journal.setReminders(true),
      ]);
      final data = await f.store.load();
      expect(data.periods.length, 1);
      expect(data.journal.entryFor(dataToday)!.note, 'Today');
      expect(data.journal.reminders, isTrue);
      final raw = f.storage.value;
      f.storage.failWrite = true;
      await expectLater(
        f.journal.saveWellbeing(DayEntry(date: dataToday, note: 'Draft')),
        throwsStateError,
      );
      expect(f.storage.value, raw);
    },
  );
  test(
    'Quick period actions and calendar editor reenter shared lock without deadlocking',
    () async {
      await PeriodQuickActions(
        diary: f.diary,
        journal: f.journal,
      ).start(dataToday);
      final editor = PeriodDayEditor(diary: f.diary, journal: f.journal);
      await editor.save(await editor.load(), {dataToday: false});
      expect((await editor.load()).contains(dataToday), isFalse);
    },
  );
  test(
    'Concurrent writers in separate service instances merge different days',
    () async {
      final other = DayJournal(
        repository: LocalJournalRepository(f.store.journalStorage),
        dataLock: f.lock,
        clock: () => dataToday.value,
      );
      await Future.wait([
        f.journal.saveWellbeing(DayEntry(date: dataToday, note: 'one')),
        other.saveWellbeing(DayEntry(date: dataToday.addDays(-1), note: 'two')),
      ]);
      expect((await f.store.load()).journal.entries.length, 2);
    },
  );
  test(
    'Stale wellbeing save and deletion cannot overwrite another edit; flow changes can merge',
    () async {
      await f.journal.saveWellbeing(DayEntry(date: dataToday, note: 'one'));
      final draft = (await f.journal.load()).entryFor(dataToday);
      await f.journal.saveWellbeing(DayEntry(date: dataToday, note: 'newer'));
      await expectLater(
        f.journal.saveWellbeing(
          DayEntry(date: dataToday, note: 'old draft'),
          expected: draft,
          checkExpected: true,
        ),
        throwsA(isA<JournalConflictException>()),
      );
      await expectLater(
        f.journal.removeWellbeing(
          dataToday,
          expected: draft,
          checkExpected: true,
        ),
        throwsA(isA<JournalConflictException>()),
      );
      final latest = (await f.journal.load()).entryFor(dataToday);
      await f.journal.setFlow(dataToday, FlowIntensity.light);
      await f.journal.saveWellbeing(
        DayEntry(date: dataToday, note: 'merged'),
        expected: latest,
        checkExpected: true,
      );
      expect(
        (await f.journal.load()).entryFor(dataToday)!.flow,
        FlowIntensity.light,
      );
    },
  );
  test(
    'Adding flow to an empty day does not invalidate an empty wellbeing draft',
    () async {
      await f.journal.setFlow(dataToday, FlowIntensity.heavy);
      await f.journal.saveWellbeing(
        DayEntry(date: dataToday, note: 'new'),
        expected: null,
        checkExpected: true,
      );
      expect(
        (await f.journal.load()).entryFor(dataToday)!.flow,
        FlowIntensity.heavy,
      );
    },
  );
  test(
    'Stale manual period correction and deletion cannot replace changed dates',
    () async {
      await f.diary.add(dataToday);
      final old = (await f.diary.load()).single;
      await f.diary.correct(old.id, dataToday.addDays(-1), end: dataToday);
      await expectLater(
        f.diary.correct(old.id, old.start, end: null, expected: old),
        throwsA(isA<PeriodRuleException>()),
      );
      await expectLater(
        f.diary.remove(old.id, expected: old),
        throwsA(isA<PeriodRuleException>()),
      );
    },
  );
  test(
    'Clear commits an empty tombstone even if a legacy cleanup fails, with no resurrection',
    () async {
      await f.diary.add(dataToday);
      await f.journal.saveWellbeing(
        DayEntry(date: dataToday, note: 'delete me'),
      );
      f.legacyJournal.value = jsonEncode({
        'version': 1,
        'entries': [DayEntry(date: dataToday, note: 'old copy').toJson()],
        'reminders': true,
      });
      f.legacyJournal.failDelete = true;
      await expectLater(f.store.clear(), throwsA(isA<LocalDataException>()));
      final raw = jsonDecode(f.storage.value!);
      expect(raw['periods'], isNull);
      expect(raw['journal'], isNull);
      f.legacyJournal.failDelete = false;
      final empty = await f.store.load();
      expect(empty.periods, isEmpty);
      expect(empty.journal.entries, isEmpty);
      expect(empty.journal.reminders, isFalse);
      expect(f.legacyJournal.value, isNull);
    },
  );
  test(
    'Corrupt or unsupported unified document blocks edits; explicit clear can recover',
    () async {
      for (final raw in [
        'broken',
        jsonEncode({'version': 99}),
        jsonEncode({
          'version': 1,
          'generation': 'bad',
          'periods': null,
          'journal': null,
        }),
      ]) {
        f.storage.value = raw;
        await expectLater(f.store.load(), throwsA(isA<LocalDataException>()));
        await expectLater(
          f.diary.add(dataToday),
          throwsA(isA<LocalDataException>()),
        );
        expect(f.storage.value, raw);
        await f.store.clear();
        expect((await f.store.load()).periods, isEmpty);
      }
    },
  );
  test(
    'Lock serializes, supports nested work, and remains usable after failures',
    () async {
      final lock = DataLock(), events = <String>[], gate = Completer<void>();
      final first = lock.run(() async {
        events.add('first');
        await gate.future;
        await lock.run(() async => events.add('nested'));
        events.add('done');
      });
      final second = lock.run(() async => events.add('second'));
      await Future<void>.delayed(Duration.zero);
      expect(events, ['first']);
      gate.complete();
      await Future.wait([first, second]);
      expect(events, ['first', 'nested', 'done', 'second']);
      await expectLater(
        lock.run(() async => throw StateError('test')),
        throwsStateError,
      );
      expect(await lock.run(() async => 42), 42);
    },
  );
}
