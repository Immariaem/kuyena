import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuyena_tracker/journal/application/day_journal.dart';
import 'package:kuyena_tracker/journal/data/local_journal_repository.dart';
import 'package:kuyena_tracker/journal/domain/day_entry.dart';
import 'package:kuyena_tracker/periods/domain/calendar_date.dart';
import '../support/memory_period_storage.dart';

void main() {
  late MemoryPeriodStorage storage;
  late DayJournal journal;
  final today = CalendarDate(2026, 10, 19);
  setUp(() {
    storage = MemoryPeriodStorage();
    journal = DayJournal(
      repository: LocalJournalRepository(storage),
      clock: () => today.value,
    );
  });
  test('Reading an empty journal does not write defaults', () async {
    expect((await journal.load()).entries, isEmpty);
    expect(storage.value, isNull);
  });
  test('Symptoms can be saved without any period or flow', () async {
    await journal.save(
      DayEntry(date: today, symptoms: {Symptom.cramps}, note: 'My note'),
    );
    final entry = (await journal.load()).entryFor(today)!;
    expect(entry.symptoms, {Symptom.cramps});
    expect(entry.flow, isNull);
    expect(entry.mood, isNull);
    expect(entry.energy, isNull);
    expect(entry.note, 'My note');
  });
  test(
    'Reopening and editing replaces the same date, preserves other days and settings',
    () async {
      final yesterday = today.addDays(-1);
      await journal.save(DayEntry(date: yesterday, flow: FlowIntensity.light));
      await journal.save(DayEntry(date: today, mood: Mood.good));
      await journal.setReminders(true);
      final reopened = DayJournal(
        repository: LocalJournalRepository(storage),
        clock: () => today.value,
      );
      await reopened.save(
        DayEntry(
          date: today,
          flow: FlowIntensity.none,
          mood: Mood.low,
          energy: 0,
        ),
      );
      final data = await reopened.load();
      expect(data.entries.length, 2);
      expect(data.reminders, isTrue);
      expect(data.entryFor(yesterday)!.flow, FlowIntensity.light);
      expect(data.entryFor(today)!.energy, 0);
      expect(data.entryFor(today)!.mood, Mood.low);
    },
  );
  test('Simultaneous saves are serialized without losing an entry', () async {
    await Future.wait([
      journal.save(DayEntry(date: today, note: 'Today')),
      journal.save(DayEntry(date: today.addDays(-1), note: 'Yesterday')),
    ]);
    expect((await journal.load()).entries.length, 2);
  });
  test('Future dates and empty observations do not create data', () async {
    await expectLater(
      journal.save(DayEntry(date: today.addDays(1), note: 'Future')),
      throwsArgumentError,
    );
    await expectLater(journal.save(DayEntry(date: today)), throwsArgumentError);
    expect(storage.value, isNull);
  });
  test('Energy bounds preserve zero and reject invalid values', () {
    expect(DayEntry(date: today, energy: 0).energy, 0);
    expect(DayEntry(date: today, energy: 100).energy, 100);
    expect(() => DayEntry(date: today, energy: -1), throwsArgumentError);
    expect(() => DayEntry(date: today, energy: 101), throwsArgumentError);
  });
  test(
    'Corrupt and unsupported documents block edits and preserve raw data',
    () async {
      for (final raw in [
        'not json',
        jsonEncode({'version': 2, 'entries': [], 'reminders': false}),
        jsonEncode({
          'version': 1,
          'entries': [
            {
              'date': '2026-02-30',
              'flow': null,
              'symptoms': [],
              'mood': null,
              'energy': null,
              'note': '',
            },
          ],
          'reminders': false,
        }),
      ]) {
        storage.value = raw;
        await expectLater(journal.load(), throwsA(isA<JournalDataException>()));
        await expectLater(
          journal.save(DayEntry(date: today, note: 'New')),
          throwsA(isA<JournalDataException>()),
        );
        await expectLater(
          journal.setReminders(true),
          throwsA(isA<JournalDataException>()),
        );
        expect(storage.value, raw);
      }
    },
  );
  test('Duplicate dates and invalid enum/energy values are rejected', () async {
    final json = DayEntry(date: today, flow: FlowIntensity.none).toJson();
    for (final entries in [
      [json, json],
      [
        {...json, 'flow': 'invalid'},
      ],
      [
        {...json, 'energy': 101},
      ],
      [
        {
          ...json,
          'symptoms': ['fatigue', 'fatigue'],
        },
      ],
    ]) {
      storage.value = jsonEncode({
        'version': 1,
        'entries': entries,
        'reminders': false,
      });
      await expectLater(journal.load(), throwsA(isA<JournalDataException>()));
    }
  });
  test('Write failure leaves the previously saved entry intact', () async {
    await journal.save(DayEntry(date: today, note: 'Saved'));
    final before = storage.value;
    storage.failWrite = true;
    await expectLater(
      journal.save(DayEntry(date: today, note: 'Draft')),
      throwsStateError,
    );
    expect(storage.value, before);
  });
  test(
    'Deleting one date removes its symptoms and preserves other days',
    () async {
      await journal.save(DayEntry(date: today, symptoms: {Symptom.fatigue}));
      await journal.save(DayEntry(date: today.addDays(-1), note: 'Keep'));
      await journal.remove(today);
      expect((await journal.load()).entryFor(today), isNull);
      expect((await journal.load()).entries.single.note, 'Keep');
    },
  );
  test(
    'Delete failure is reported, clearing removes entries and preferences',
    () async {
      await journal.save(DayEntry(date: today, note: 'Saved'));
      await journal.setReminders(true);
      final before = storage.value;
      storage.failDelete = true;
      await expectLater(journal.clear(), throwsStateError);
      expect(storage.value, before);
      storage.failDelete = false;
      await journal.clear();
      expect(storage.value, isNull);
      expect((await journal.load()).reminders, isFalse);
    },
  );
  test(
    'wellbeing saves merge the latest bleeding and preserve zero energy',
    () async {
      await journal.setFlow(today, FlowIntensity.light);
      final draft = DayEntry(
        date: today,
        symptoms: {Symptom.headache},
        energy: 0,
      );
      await journal.setFlow(today, FlowIntensity.heavy);
      await journal.saveWellbeing(draft);
      final entry = (await journal.load()).entryFor(today)!;
      expect(entry.flow, FlowIntensity.heavy);
      expect(entry.symptoms, {Symptom.headache});
      expect(entry.energy, 0);
    },
  );
  test(
    'deleting wellbeing preserves bleeding, other days and reminders',
    () async {
      await journal.save(
        DayEntry(
          date: today,
          flow: FlowIntensity.none,
          symptoms: {Symptom.cramps},
          mood: Mood.low,
          energy: 0,
          note: 'note',
        ),
      );
      await journal.saveWellbeing(
        DayEntry(date: today.addDays(-1), note: 'Keep'),
      );
      await journal.setReminders(true);
      await journal.removeWellbeing(today);
      final data = await journal.load();
      expect(data.entryFor(today)!.flow, FlowIntensity.none);
      expect(data.entryFor(today)!.hasWellbeing, isFalse);
      expect(data.entryFor(today.addDays(-1))!.note, 'Keep');
      expect(data.reminders, isTrue);
    },
  );
  test(
    'bleeding changes and removal preserve wellbeing; empty records disappear',
    () async {
      await journal.saveWellbeing(
        DayEntry(date: today, symptoms: {Symptom.fatigue}, energy: 0),
      );
      await journal.setFlow(today, FlowIntensity.light);
      await journal.setFlow(today, null);
      final entry = (await journal.load()).entryFor(today)!;
      expect(entry.flow, isNull);
      expect(entry.symptoms, {Symptom.fatigue});
      expect(entry.energy, 0);
      await journal.removeWellbeing(today);
      expect((await journal.load()).entryFor(today), isNull);
    },
  );
  test(
    'queued independent changes retain both period and wellbeing inputs',
    () async {
      await Future.wait([
        journal.saveWellbeing(
          DayEntry(date: today, symptoms: {Symptom.fatigue}),
        ),
        journal.setFlow(today, FlowIntensity.light),
      ]);
      final entry = (await journal.load()).entryFor(today)!;
      expect(entry.symptoms, {Symptom.fatigue});
      expect(entry.flow, FlowIntensity.light);
    },
  );
  test(
    'empty wellbeing, future inputs and failed writes preserve existing bleeding',
    () async {
      await journal.setFlow(today, FlowIntensity.light);
      final before = storage.value;
      await expectLater(
        journal.saveWellbeing(DayEntry(date: today)),
        throwsArgumentError,
      );
      await expectLater(
        journal.saveWellbeing(DayEntry(date: today.addDays(1), note: 'future')),
        throwsArgumentError,
      );
      await expectLater(
        journal.setFlow(today.addDays(1), FlowIntensity.none),
        throwsArgumentError,
      );
      storage.failWrite = true;
      await expectLater(
        journal.saveWellbeing(DayEntry(date: today, note: 'draft')),
        throwsStateError,
      );
      await expectLater(journal.removeWellbeing(today), throwsStateError);
      expect(storage.value, before);
    },
  );
}
