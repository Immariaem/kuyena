import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuyena_tracker/profile/domain/user_profile.dart';
import 'package:kuyena_tracker/data/storage/local_app_store.dart';
import 'package:kuyena_tracker/data/backup/backup_document.dart';
import 'package:kuyena_tracker/journal/domain/day_entry.dart';
import 'package:kuyena_tracker/periods/application/period_timeline.dart';
import 'package:kuyena_tracker/periods/domain/calendar_date.dart';
import 'package:kuyena_tracker/periods/domain/cycle_estimate.dart';
import 'package:kuyena_tracker/periods/domain/period.dart';
import '../data/data_fixture.dart';

void main() {
  late DataFixture f;
  setUp(() => f = DataFixture());
  final start = CalendarDate(2026, 10, 17), end = CalendarDate(2026, 10, 21);
  UserProfile profile() => UserProfile(
    completed: true,
    step: 8,
    lastPeriodStart: start,
    lastPeriodEnd: end,
    periodLength: 'medium',
  );
  test(
    'Profile v1 remains readable without inventing end; v2 rejects inconsistent or missing dates',
    () {
      final old = profile().toJson()
        ..['version'] = 1
        ..remove('lastPeriodEnd')
        ..remove('lastPeriodOngoing');
      final restored = UserProfile.decode(jsonEncode(old));
      expect(restored.lastPeriodEnd, isNull);
      expect(restored.lastPeriodDuration, isNull);
      expect(restored.lastPeriodOngoing, isFalse);
      expect(UserProfile.decode(profile().encode()).lastPeriodDuration, 5);
      for (final invalid in [
        {...profile().toJson(), 'lastPeriodEnd': '2026-10-16'},
        {...profile().toJson(), 'lastPeriodStart': null},
        {...profile().toJson(), 'lastPeriodOngoing': true},
        {...profile().toJson(), 'lastPeriodEnd': false},
        {...profile().toJson()}..remove('lastPeriodOngoing'),
      ]) {
        expect(
          () => UserProfile.decode(jsonEncode(invalid)),
          throwsFormatException,
        );
      }
      expect(
        UserProfile(
          completed: true,
          lastPeriodStart: start,
          lastPeriodEnd: start,
        ).lastPeriodDuration,
        1,
      );
    },
  );
  test(
    'Completion commits inclusive range; actual days enter calendar and predictions stay computed',
    () async {
      await f.store.saveProfile(profile(), expected: null, today: dataToday);
      final data = await f.store.load(), p = (await f.diary.load()).single;
      expect((p.start, p.end, p.documentedDayCount), (start, end, 5));
      expect(p.isOngoing, isFalse);
      final timeline = PeriodTimeline.from(
        periods: data.periods,
        entries: data.journal.entries,
        periodDays: data.journal.periodDays,
        asOf: dataToday,
      );
      for (var d = start; d.compareTo(end) <= 0; d = d.addDays(1)) {
        expect(timeline.periods.single.includes(d, asOf: dataToday), isTrue);
      }
      expect(
        timeline.periods.single.includes(end.addDays(1), asOf: dataToday),
        isFalse,
      );
      final estimate = CycleEstimate.fromPeriods(data.periods)!;
      expect(estimate.expectedStart, CalendarDate(2026, 11, 14));
      expect(estimate.source, CycleEstimateSource.populationReference);
      expect(estimate.earliestOvulation, CalendarDate(2026, 10, 29));
      expect(estimate.latestOvulation, CalendarDate(2026, 11, 4));
      expect(data.periods.length, 1);
      expect(data.journal.periodDays, isEmpty);
    },
  );
  test('Explicit ongoing period has no fabricated end or duration', () async {
    await f.store.saveProfile(
      UserProfile(
        completed: true,
        lastPeriodStart: start,
        lastPeriodOngoing: true,
      ),
      expected: null,
      today: dataToday,
    );
    final data = await f.store.load();
    expect(data.periods.single.isOngoing, isTrue);
    expect(data.periods.single.end, isNull);
    expect(data.profile!.lastPeriodDuration, isNull);
  });
  test(
    'Adding a known end to matching unknown start avoids duplicate and retains wellbeing',
    () async {
      await f.diary.add(start);
      await f.journal.saveWellbeing(DayEntry(date: dataToday, note: 'Keep'));
      await f.store.saveProfile(profile(), expected: null, today: dataToday);
      final data = await f.store.load();
      expect(data.periods.length, 1);
      expect(data.periods.single.end, end);
      expect(data.journal.entries.single.note, 'Keep');
      await f.store.saveProfile(
        profile(),
        expected: profile(),
        today: dataToday,
      );
      expect((await f.store.load()).periods.length, 1);
    },
  );
  test(
    'Overlapping or future range fails without changing data; existing recorded end is protected',
    () async {
      await f.diary.add(start, end: end.addDays(-1));
      final before = f.storage.value;
      await expectLater(
        f.store.saveProfile(profile(), expected: null, today: dataToday),
        throwsA(isA<LocalDataException>()),
      );
      expect(f.storage.value, before);
      await f.store.clear();
      await f.diary.add(end, end: end.addDays(1));
      final beforeOther = f.storage.value;
      await expectLater(
        f.store.saveProfile(profile(), expected: null, today: dataToday),
        throwsA(isA<LocalDataException>()),
      );
      expect(f.storage.value, beforeOther);
      await f.store.clear();
      await expectLater(
        f.store.saveProfile(
          UserProfile(
            completed: true,
            lastPeriodStart: start,
            lastPeriodEnd: dataToday.addDays(1),
          ),
          expected: null,
          today: dataToday,
        ),
        throwsA(isA<LocalDataException>()),
      );
      expect((await f.store.load()).periods, isEmpty);
    },
  );
  test(
    'New end is included in backup and validated on import; failed commit is atomic',
    () async {
      f.storage.failWrite = true;
      await expectLater(
        f.store.saveProfile(profile(), expected: null, today: dataToday),
        throwsStateError,
      );
      expect(f.storage.value, isNull);
      f.storage.failWrite = false;
      await f.store.saveProfile(profile(), expected: null, today: dataToday);
      final raw = await f.service().jsonExport();
      await f.store.clear();
      await f.service().restore(
        await f.service().preview(Uint8List.fromList(utf8.encode(raw))),
      );
      final data = await f.store.load();
      expect(data.profile!.lastPeriodEnd, end);
      expect(data.periods.single.documentedDayCount, 5);
      final bad = jsonDecode(raw);
      bad['profile']['lastPeriodEnd'] = dataToday.addDays(1).iso;
      expect(
        () => BackupDocument.decode(jsonEncode(bad), today: dataToday),
        throwsA(isA<BackupException>()),
      );
    },
  );
  test(
    'Personal report overrides population reference, observed mean replaces both without blending',
    () {
      final a = Period(id: 'a', start: start, end: end);
      final population = CycleEstimate.fromPeriods([a])!;
      expect(population.lengthInDays, 28);
      expect(population.cycleCount, 0);
      expect(population.isPopulationReference, isTrue);
      final own = CycleEstimate.fromPeriods([a], initialLength: 31)!;
      expect(own.source, CycleEstimateSource.selfReported);
      expect(own.lengthInDays, 31);
      final b = Period(
        id: 'b',
        start: start.addDays(26),
        end: start.addDays(30),
      );
      final c = Period(id: 'c', start: start.addDays(56));
      final estimate = CycleEstimate.fromPeriods([a, b, c], initialLength: 31)!;
      expect(estimate.source, CycleEstimateSource.observedMean);
      expect(estimate.lengthInDays, 28);
      expect(estimate.cycleCount, 2);
      expect(estimate.expectedStart, start.addDays(84));
      expect(CycleEstimate.fromPeriods([]), isNull);
    },
  );
}
