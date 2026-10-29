import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuyena_tracker/profile/application/profile_controller.dart';
import 'package:kuyena_tracker/profile/domain/user_profile.dart';
import 'package:kuyena_tracker/data/storage/local_app_store.dart';
import 'package:kuyena_tracker/data/backup/backup_document.dart';
import 'package:kuyena_tracker/journal/domain/day_entry.dart';
import 'package:kuyena_tracker/periods/domain/calendar_date.dart';
import 'package:kuyena_tracker/periods/domain/cycle_estimate.dart';
import 'package:kuyena_tracker/periods/domain/period.dart';
import '../data/data_fixture.dart';

void main() {
  late DataFixture f;
  setUp(() => f = DataFixture());
  UserProfile example({bool completed = true}) => UserProfile(
    completed: completed,
    step: 8,
    lastPeriodStart: dataToday.addDays(-10),
    periodLength: 'medium',
    cycleLength: 'long',
    exactCycleDays: 30,
    regularity: 'mostly',
    goals: {'understand', 'patterns'},
    symptoms: {Symptom.bloating, Symptom.skinChanges},
    trackMoodEnergy: false,
    trackNotes: true,
    movements: {'walking', 'swimming'},
    activity: 'moderate',
    interests: {'gentle'},
    excludedActivities: 'Sprünge',
    limitations: 'Testangabe',
    diet: 'vegan',
    allergies: {'nuts', 'soy'},
    otherAllergies: 'Test',
    dislikedIngredients: 'Pilze',
    dailyReminder: true,
    periodReminder: true,
    reminderMinute: 1085,
  );
  test('Unknown answers stay unknown and all preference fields round-trip', () {
    final empty = UserProfile.decode(UserProfile().encode());
    expect(empty.exactCycleDays, isNull);
    expect(empty.lastPeriodStart, isNull);
    expect(empty.trackMoodEnergy, isNull);
    expect(empty.goals, isEmpty);
    expect(UserProfile.decode(example().encode()).encode(), example().encode());
    for (final json in [
      {...example().toJson(), 'exactCycleDays': 0},
      {...example().toJson(), 'reminderMinute': 1440},
      {
        ...example().toJson(),
        'goals': ['unknown'],
      },
      {
        ...example().toJson(),
        'goals': ['understand', 'understand'],
      },
      {
        ...example().toJson(),
        'symptoms': ['unknown'],
      },
      {
        ...example().toJson(),
        'allergies': ['none', 'nuts'],
      },
      {...example().toJson(), 'trackNotes': 'yes'},
      {...example().toJson(), 'limitations': 'x' * 2001},
    ]) {
      expect(() => UserProfile.decode(jsonEncode(json)), throwsFormatException);
    }
  });
  test(
    'Drafts resume without bleeding; completion commits reported start and prefs atomically',
    () async {
      final draft = example(completed: false);
      await f.store.saveProfile(draft, expected: null, today: dataToday);
      expect((await f.store.load()).periods, isEmpty);
      final profile = example();
      await f.store.saveProfile(profile, expected: draft, today: dataToday);
      final data = await f.store.load();
      expect(data.profile!.encode(), profile.encode());
      expect(data.periods.single.start, dataToday.addDays(-10));
      expect(data.periods.single.end, isNull);
      expect(data.periods.single.isOngoing, isFalse);
      expect(data.journal.reminders, isTrue);
      await f.store.saveProfile(profile, expected: profile, today: dataToday);
      expect((await f.store.load()).periods.length, 1);
      final controller = ProfileController(
        store: f.store,
        today: () => dataToday,
      );
      await controller.load();
      expect(controller.value!.completed, isTrue);
    },
  );
  test(
    'Existing dates and observations survive onboarding and remain in one verified document',
    () async {
      await f.diary.add(dataToday.addDays(-10), end: dataToday.addDays(-7));
      await f.journal.saveWellbeing(
        DayEntry(date: dataToday, symptoms: {Symptom.cramps}, note: 'Keep'),
      );
      await f.store.saveProfile(example(), expected: null, today: dataToday);
      final data = await f.store.load();
      expect(data.periods.length, 1);
      expect(data.periods.single.end, dataToday.addDays(-7));
      expect(data.journal.entries.single.note, 'Keep');
      await Future.wait([
        f.journal.saveWellbeing(
          DayEntry(date: dataToday.addDays(-1), note: 'Parallel'),
        ),
        f.diary.add(dataToday, isOngoing: true),
      ]);
      expect((await f.store.load()).profile!.encode(), example().encode());
    },
  );
  test(
    'Stale profile edits fail; unrelated fresh day entries merge; failed writes preserve all sections',
    () async {
      await f.store.saveProfile(example(), expected: null, today: dataToday);
      final old = (await f.store.load()).profile;
      final updated = UserProfile.fromJson({
        ...old!.toJson(),
        'diet': 'vegetarian',
      });
      await f.journal.saveWellbeing(
        DayEntry(date: dataToday, note: 'Newer day'),
      );
      await f.store.saveProfile(updated, expected: old, today: dataToday);
      await expectLater(
        f.store.saveProfile(old, expected: old, today: dataToday),
        throwsA(isA<LocalDataException>()),
      );
      expect((await f.store.load()).journal.entries.single.note, 'Newer day');
      final before = f.storage.value;
      f.storage.failWrite = true;
      await expectLater(
        f.store.saveProfile(old, expected: updated, today: dataToday),
        throwsStateError,
      );
      expect(f.storage.value, before);
    },
  );
  test(
    'Conflicting or future setup dates do not overwrite existing records',
    () async {
      await f.diary.add(dataToday.addDays(-12), end: dataToday.addDays(-7));
      final before = f.storage.value;
      await expectLater(
        f.store.saveProfile(example(), expected: null, today: dataToday),
        throwsA(isA<LocalDataException>()),
      );
      expect(f.storage.value, before);
      final future = UserProfile(
        completed: true,
        lastPeriodStart: dataToday.addDays(1),
      );
      await expectLater(
        f.store.saveProfile(future, expected: null, today: dataToday),
        throwsA(isA<LocalDataException>()),
      );
      expect(f.storage.value, before);
    },
  );
  test(
    'Legacy envelope v1 loads and next write preserves old data while upgrading profile section',
    () async {
      await f.diary.add(dataToday);
      final old = jsonDecode(f.storage.value!) as Map<String, dynamic>;
      old['version'] = 1;
      old.remove('profile');
      f.storage.value = jsonEncode(old);
      expect((await f.store.load()).profile, isNull);
      await f.store.saveProfile(
        UserProfile(completed: true),
        expected: null,
        today: dataToday,
      );
      final current = jsonDecode(f.storage.value!);
      expect(current['version'], 2);
      expect((await f.store.load()).periods.single.start, dataToday);
    },
  );
  test(
    'Export v3 restores preferences and records together; v2 backups are still supported',
    () async {
      await f.store.saveProfile(example(), expected: null, today: dataToday);
      await f.journal.saveWellbeing(
        DayEntry(date: dataToday, symptoms: {Symptom.sleepProblems}),
      );
      final raw = await f.service().jsonExport();
      final parsed = jsonDecode(raw);
      expect(parsed['version'], 3);
      expect(parsed['profile']['diet'], 'vegan');
      await f.store.clear();
      expect((await f.store.load()).profile, isNull);
      final preview = await f.service().preview(
        Uint8List.fromList(utf8.encode(raw)),
      );
      await f.service().restore(preview);
      expect((await f.store.load()).profile!.encode(), example().encode());
      expect((await f.store.load()).journal.entries.single.symptoms, {
        Symptom.sleepProblems,
      });
      parsed['version'] = 2;
      parsed.remove('profile');
      expect(
        BackupDocument.decode(jsonEncode(parsed), today: dataToday).profile,
        isNull,
      );
      parsed['version'] = 3;
      parsed['profile'] = {
        ...example().toJson(),
        'lastPeriodStart': dataToday.addDays(1).iso,
      };
      expect(
        () => BackupDocument.decode(jsonEncode(parsed), today: dataToday),
        throwsA(isA<BackupException>()),
      );
    },
  );
  test(
    'Damaged profile blocks partial writes and can be recovered through explicit full clear',
    () async {
      await f.store.saveProfile(example(), expected: null, today: dataToday);
      final raw = jsonDecode(f.storage.value!);
      raw['profile'] = 'broken';
      f.storage.value = jsonEncode(raw);
      await expectLater(
        f.diary.add(dataToday),
        throwsA(isA<LocalDataException>()),
      );
      await f.store.clear();
      final empty = await f.store.load();
      expect(empty.profile, isNull);
      expect(empty.periods, isEmpty);
      expect(empty.journal.entries, isEmpty);
    },
  );
  test(
    'Initial exact length needs a start; observed mean replaces the self-reported fallback',
    () {
      final start = CalendarDate(2026, 1, 1);
      expect(CycleEstimate.fromPeriods([], initialLength: 28), isNull);
      final first = Period(id: '1', start: start);
      expect(CycleEstimate.fromPeriods([first]), isNull);
      final initial = CycleEstimate.fromPeriods([first], initialLength: 31)!;
      expect(initial.isInitial, isTrue);
      expect(initial.expectedStart, start.addDays(31));
      final observed = CycleEstimate.fromPeriods([
        first,
        Period(id: '2', start: start.addDays(27)),
      ], initialLength: 31)!;
      expect(observed.isInitial, isFalse);
      expect(observed.lengthInDays, 27);
      expect(observed.expectedStart, start.addDays(54));
      final rounded = CycleEstimate.fromPeriods([
        first,
        Period(id: '2', start: start.addDays(27)),
        Period(id: '3', start: start.addDays(57)),
      ])!;
      expect(rounded.meanLengthInDays, 28.5);
      expect(rounded.lengthInDays, 29);
    },
  );
}
