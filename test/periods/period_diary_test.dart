import 'package:flutter_test/flutter_test.dart';
import 'package:kuyena_tracker/periods/application/period_diary.dart';
import 'package:kuyena_tracker/periods/data/local_period_repository.dart';
import 'package:kuyena_tracker/periods/domain/calendar_date.dart';
import 'package:kuyena_tracker/periods/domain/period.dart';

import '../support/memory_period_storage.dart';

void main() {
  late MemoryPeriodStorage storage;
  late PeriodDiary diary;
  List<CalendarDate> starts(List<Period> periods) =>
      periods.map((period) => period.start).toList();

  final today = CalendarDate(2026, 10, 18);
  final earlier = CalendarDate(2026, 9, 12);
  final corrected = CalendarDate(2026, 9, 13);

  PeriodDiary createDiary() => PeriodDiary(
    repository: LocalPeriodRepository(storage),
    clock: () => DateTime(2026, 10, 18),
  );

  setUp(() {
    storage = MemoryPeriodStorage();
    diary = createDiary();
  });

  test(
    'Mehrere Einträge bleiben nach Neuaufbau des Services erhalten',
    () async {
      await diary.add(earlier);
      await diary.add(today);
      expect(starts(await createDiary().load()), [today, earlier]);
    },
  );

  test(
    'Doppelter Tag wird ohne Veränderung vorhandener Daten abgelehnt',
    () async {
      await diary.add(today);
      final before = storage.value;
      await expectLater(diary.add(today), throwsA(isA<PeriodRuleException>()));
      expect(storage.value, before);
    },
  );

  test(
    'Heute ist erlaubt, ein künftiger Beobachtungstag wird abgelehnt',
    () async {
      await diary.add(today);
      await expectLater(
        diary.add(CalendarDate(2026, 10, 19)),
        throwsA(isA<PeriodRuleException>()),
      );
      expect(starts(await diary.load()), [today]);
    },
  );

  test('Korrektur erhält die übrige Historie', () async {
    await diary.add(earlier);
    await diary.add(today);
    final original = (await diary.load()).last;
    expect(
      starts(await diary.correct(original.id, corrected, end: original.end)),
      [today, corrected],
    );
    expect(starts(await createDiary().load()), [today, corrected]);
  });

  test('Korrektur auf einen bereits belegten Tag ist nicht erlaubt', () async {
    await diary.add(earlier);
    await diary.add(today);
    await expectLater(
      diary.correct((await diary.load()).last.id, today, end: null),
      throwsA(isA<PeriodRuleException>()),
    );
    expect(starts(await diary.load()), [today, earlier]);
  });

  test(
    'Einzelnes Löschen erhält andere Einträge auch nach erneutem Laden',
    () async {
      await diary.add(earlier);
      await diary.add(today);
      await diary.remove((await diary.load()).first.id);
      expect(starts(await createDiary().load()), [earlier]);
    },
  );

  test(
    'Alle löschen entfernt das Dokument statt leerer Gesundheitsdatenreste',
    () async {
      await diary.add(today);
      expect(await diary.clear(), isEmpty);
      expect(storage.value, isNull);
      expect(starts(await createDiary().load()), isEmpty);
    },
  );

  test('Fehlgeschlagenes Speichern wird gemeldet und blockiert spätere Versuche nicht', () async {
    await diary.add(earlier);
    storage.failWrite = true;
    await expectLater(diary.add(today), throwsStateError);
    expect(starts(await diary.load()), [earlier]);
    storage.failWrite = false;
    expect(starts(await diary.add(today)), [today, earlier]);
  });

  test(
    'Fehlgeschlagenes Löschen wird gemeldet und erhält die gespeicherten Daten',
    () async {
      await diary.add(today);
      storage.failDelete = true;
      await expectLater(
        diary.remove((await diary.load()).first.id),
        throwsStateError,
      );
      expect(starts(await createDiary().load()), [today]);
    },
  );

  test('Gleichzeitig angestoßene Vorgänge verlieren innerhalb einer Instanz keine Einträge', () async {
    await Future.wait([diary.add(earlier), diary.add(today)]);
    expect(starts(await diary.load()), [today, earlier]);
  });

  test('Ende kann ergänzt und entfernt werden; Kennung bleibt nach Neustart erhalten', () async {
    final initial = (await diary.add(earlier)).single;
    final end = CalendarDate(2026, 9, 16);
    await diary.correct(initial.id, corrected, end: end);
    final reloaded = (await createDiary().load()).single;
    expect(
      (reloaded.id, reloaded.start, reloaded.end),
      (initial.id, corrected, end),
    );

    await diary.correct(reloaded.id, reloaded.start, end: null);
    final withoutEnd = (await createDiary().load()).single;
    expect((withoutEnd.id, withoutEnd.end), (initial.id, null));
  });

  test('Ungültiges Ende und ungültige Korrektur verändern gespeicherte Daten nicht', () async {
    final initial = (await diary.add(earlier, end: corrected)).single;
    final before = storage.value;
    await expectLater(
      diary.add(today, end: earlier),
      throwsA(isA<PeriodRuleException>()),
    );
    await expectLater(
      diary.correct(initial.id, today, end: corrected),
      throwsA(isA<PeriodRuleException>()),
    );
    expect(storage.value, before);
  });

  test('Ein künftiges Ende wird wie ein künftiger Beginn abgelehnt', () async {
    await expectLater(
      diary.add(today, end: CalendarDate(2026, 10, 19)),
      throwsA(isA<PeriodRuleException>()),
    );
    expect(storage.value, isNull);
  });

  test('Einträge werden nach Kennung korrigiert und gelöscht', () async {
    final original = (await diary.add(earlier, end: corrected)).single;
    await diary.add(today);
    await diary.correct(original.id, CalendarDate(2026, 9, 11), end: corrected);
    await expectLater(
      diary.correct('fehlt', today, end: null),
      throwsA(isA<PeriodRuleException>()),
    );
    await expectLater(
      diary.remove('fehlt'),
      throwsA(isA<PeriodRuleException>()),
    );
    await diary.remove(original.id);
    expect(starts(await createDiary().load()), [today]);
  });

  test('Eine bereits vergebene Kennung überschreibt keinen Eintrag', () async {
    final fixedIds = PeriodDiary(
      repository: LocalPeriodRepository(storage),
      clock: () => today.value,
      idGenerator: () => 'gleiche-kennung',
    );
    await fixedIds.add(earlier);
    final before = storage.value;
    await expectLater(fixedIds.add(today), throwsStateError);
    expect(storage.value, before);
  });
}
