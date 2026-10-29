import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuyena_tracker/main.dart';
import 'package:kuyena_tracker/journal/application/day_journal.dart';
import 'package:kuyena_tracker/journal/data/local_journal_repository.dart';
import 'package:kuyena_tracker/journal/domain/day_entry.dart';
import 'package:kuyena_tracker/periods/application/period_diary.dart';
import 'package:kuyena_tracker/periods/domain/calendar_date.dart';
import 'package:kuyena_tracker/periods/data/local_period_repository.dart';

import '../support/memory_period_storage.dart';

MemoryPeriodStorage savedPeriod({
  String start = '2026-10-20',
  String? end,
  bool ongoing = false,
}) => MemoryPeriodStorage(
  jsonEncode({
    'version': 3,
    'periods': [
      {'id': 'test', 'start': start, 'end': end, 'ongoing': ongoing},
    ],
  }),
);

Future<MemoryPeriodStorage> openHome(
  WidgetTester tester, {
  MemoryPeriodStorage? storage,
  MemoryPeriodStorage? journalStorage,
  DateTime Function()? clock,
}) async {
  storage ??= MemoryPeriodStorage();
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  await tester.pumpWidget(
    ZyklusApp(
      key: UniqueKey(),
      journal: DayJournal(
        repository: LocalJournalRepository(
          journalStorage ?? MemoryPeriodStorage(),
        ),
        clock: clock ?? () => DateTime(2026, 10, 22),
      ),
      diary: PeriodDiary(
        repository: LocalPeriodRepository(storage),
        clock: clock ?? () => DateTime(2026, 10, 22),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return storage;
}

void main() {
  testWidgets('Home kennzeichnet Beispieldaten und speichert sie nicht', (
    tester,
  ) async {
    final storage = await openHome(tester);
    expect(find.text('Hey, girl!'), findsOneWidget);
    expect(find.text('3 Days'), findsNothing);
    expect(find.text('Kein Eintrag'), findsOneWidget);
    expect(find.text('Demo'), findsOneWidget);
    expect(storage.value, isNull);
    await tester.tap(find.text('Demo'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('keine Auswertung deiner gespeicherten Einträge'),
      findsOneWidget,
    );
    expect(storage.value, isNull);
  });

  testWidgets('Symptom cards follow the selected day without writing data', (
    tester,
  ) async {
    final days = MemoryPeriodStorage();
    await LocalJournalRepository(days).save(
      JournalData(
        entries: [
          DayEntry(
            date: CalendarDate(2026, 10, 22),
            symptoms: {Symptom.headache, Symptom.fatigue},
          ),
        ],
      ),
    );
    final before = days.value;
    await openHome(tester, journalStorage: days);
    expect(find.text('Logged symptoms'), findsOneWidget);
    expect(find.text('Headache\nFatigue'), findsOneWidget);
    expect(find.text('Possible symptoms'), findsNothing);
    expect(find.text('Phase unknown'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('date-2026-10-21')));
    await tester.pumpAndSettle();
    expect(find.text('Possible symptoms'), findsOneWidget);
    expect(find.text('Example · not a prediction'), findsOneWidget);
    expect(find.text('Headache\nFatigue'), findsNothing);
    final card = find.byKey(const ValueKey('home-symptoms-card'));
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        'Für den 21.10.2026 sind keine Symptome eingetragen.',
      ),
      findsOneWidget,
    );
    expect(days.value, before);
  });

  testWidgets('Estimated phase changes with the date and explains its limits', (
    tester,
  ) async {
    final storage = MemoryPeriodStorage(
      jsonEncode({
        'version': 3,
        'periods': [
          {
            'id': 'a',
            'start': '2026-08-01',
            'end': '2026-08-05',
            'ongoing': false,
          },
          {
            'id': 'b',
            'start': '2026-08-29',
            'end': '2026-09-02',
            'ongoing': false,
          },
          {
            'id': 'c',
            'start': '2026-09-26',
            'end': '2026-09-30',
            'ongoing': false,
          },
        ],
      }),
    );
    final before = storage.value;
    await openHome(
      tester,
      storage: storage,
      clock: () => DateTime(2026, 10, 7),
    );
    expect(find.text('Estimated phase'), findsOneWidget);
    expect(find.text('Follicular phase'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('date-2026-10-08')));
    await tester.pumpAndSettle();
    expect(find.text('Around ovulation'), findsOneWidget);
    expect(find.text('Calendar estimate'), findsOneWidget);
    final card = find.byKey(const ValueKey('home-phase-card'));
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.textContaining('nicht bestätigen'), findsOneWidget);
    expect(storage.value, before);
  });

  testWidgets(
    'Failed reads hide stale symptoms and phase; retry restores them',
    (tester) async {
      final days = MemoryPeriodStorage();
      await LocalJournalRepository(days).save(
        JournalData(
          entries: [
            DayEntry(
              date: CalendarDate(2026, 10, 22),
              flow: FlowIntensity.light,
              symptoms: {Symptom.fatigue},
            ),
          ],
        ),
      );
      await openHome(tester, journalStorage: days);
      expect(find.text('Menstruation'), findsOneWidget);
      expect(find.text('Logged symptoms'), findsOneWidget);
      days.failRead = true;
      await tester.tap(find.text('Heute').first);
      await tester.pumpAndSettle();
      expect(find.text('Unavailable'), findsNWidgets(2));
      expect(find.text('Menstruation'), findsNothing);
      expect(find.text('Logged symptoms'), findsNothing);
      expect(find.text('Possible symptoms'), findsNothing);
      days.failRead = false;
      final card = find.byKey(const ValueKey('home-phase-card'));
      await tester.ensureVisible(card);
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.text('Menstruation'), findsOneWidget);
      expect(find.text('Logged symptoms'), findsOneWidget);
    },
  );

  testWidgets('All logged symptoms fit phone and desktop with larger text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final days = MemoryPeriodStorage();
    await LocalJournalRepository(days).save(
      JournalData(
        entries: [
          DayEntry(
            date: CalendarDate(2026, 10, 22),
            symptoms: Symptom.values.toSet(),
          ),
        ],
      ),
    );
    for (final size in [
      const Size(320, 568),
      const Size(412, 917),
      const Size(900, 700),
      const Size(1440, 1000),
    ]) {
      tester.view.physicalSize = size;
      await openHome(tester, journalStorage: days);
      final symptoms = find.text(
        'Cramps\nHeadache\nFatigue\nBreast tenderness',
      );
      expect(symptoms, findsOneWidget);
      await tester.ensureVisible(symptoms);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$size');
    }
  });

  testWidgets('Plus öffnet Erfassung; Abbrechen erzeugt keinen Eintrag', (
    tester,
  ) async {
    final storage = await openHome(tester);
    await tester.tap(find.byKey(const ValueKey('home-log-button')));
    await tester.pumpAndSettle();
    expect(find.text('Choose a date'), findsOneWidget);
    await tester.ensureVisible(find.text('Cancel').last);
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    expect(storage.value, isNull);
    expect(find.text('Kein Eintrag'), findsOneWidget);
  });

  testWidgets('Plus wartet bei Lesefehler mit der Erfassung', (tester) async {
    final journalStorage = MemoryPeriodStorage()..failRead = true;
    await openHome(tester, journalStorage: journalStorage);
    await tester.tap(find.byKey(const ValueKey('home-log-button')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsNothing);
    expect(find.textContaining('Could not load this day.'), findsOneWidget);
  });

  testWidgets('Home bleibt auf kleinem Handy und im Browser bedienbar', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    for (final size in [
      const Size(320, 568),
      const Size(412, 917),
      const Size(900, 700),
      const Size(1024, 768),
      const Size(1440, 1000),
    ]) {
      tester.view.physicalSize = size;
      await openHome(tester);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('home-nav-For you')));
      await tester.pumpAndSettle();
      expect(find.text('Recommendations'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('home-nav-Home')));
      await tester.pumpAndSettle();
      expect(find.text('Hey, girl!'), findsOneWidget);
    }
  });

  testWidgets(
    'Heute steht beim Öffnen mittig; Heute setzt die Auswahl zurück',
    (tester) async {
      await openHome(tester);
      final wheel = find.byKey(const ValueKey('curved-date-slider'));
      final today = find.byKey(const ValueKey('date-2026-10-22'));
      expect(
        tester.getCenter(today).dx,
        closeTo(tester.getCenter(wheel).dx, 1),
      );
      await tester.tap(find.byKey(const ValueKey('date-2026-10-23')));
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(find.byKey(const ValueKey('date-2026-10-23'))).dx,
        closeTo(tester.getCenter(wheel).dx, 1),
      );
      await tester.tap(find.text('Heute'));
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(today).dx,
        closeTo(tester.getCenter(wheel).dx, 1),
      );
    },
  );

  testWidgets(
    'Breite Webansicht hat Navigation und nebeneinanderliegende Bereiche',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await openHome(tester);
      expect(find.byKey(const ValueKey('desktop-navigation')), findsOneWidget);
      final cycle = tester.getRect(
        find.byKey(const ValueKey('desktop-cycle-panel')),
      );
      final info = tester.getRect(
        find.byKey(const ValueKey('desktop-information-panel')),
      );
      expect(info.left, greaterThan(cycle.right));
      expect(info.top, closeTo(cycle.top, 1));
      await tester.tap(find.byTooltip('Nächster Tag'));
      await tester.pumpAndSettle();
      expect(find.textContaining('23. Oktober 2026'), findsOneWidget);
      await tester.tap(find.text('Heute'));
      await tester.pumpAndSettle();
      expect(find.textContaining('22. Oktober 2026'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Tagesauswahl bleibt beim Wechsel zwischen Handy und Web erhalten',
    (tester) async {
      tester.view.physicalSize = const Size(412, 917);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final storage = await openHome(tester);
      await tester.tap(find.byKey(const ValueKey('date-2026-10-23')));
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(1440, 1000);
      await tester.pumpAndSettle();
      expect(find.textContaining('23. Oktober 2026'), findsOneWidget);
      tester.view.physicalSize = const Size(320, 568);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('desktop-home')), findsNothing);
      expect(
        tester.getCenter(find.byKey(const ValueKey('date-2026-10-23'))).dx,
        closeTo(
          tester.getCenter(find.byKey(const ValueKey('curved-date-slider'))).dx,
          1,
        ),
      );
      expect(storage.value, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Unbekanntes Ende gilt nicht als aktive Periode und erfindet keinen Countdown',
    (tester) async {
      final storage = savedPeriod();
      final before = storage.value;
      await openHome(tester, storage: storage);
      expect(find.text('Noch offen'), findsOneWidget);
      expect(find.text('Bis zur nächsten Periode'), findsOneWidget);
      expect(find.textContaining('Ende unbekannt'), findsOneWidget);
      expect(find.text('3 Days'), findsNothing);
      expect(storage.value, before);
      await tester.tap(find.byKey(const ValueKey('period-status-ring')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Ein unbekanntes Ende bestätigt nicht'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Datumsrad berechnet den dokumentierten Periodentag neu und beachtet das Ende',
    (tester) async {
      final storage = savedPeriod(end: '2026-10-22');
      final before = storage.value;
      await openHome(tester, storage: storage);
      expect(find.text('Deine Periode'), findsOneWidget);
      expect(find.text('Tag 3'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('date-2026-10-21')));
      await tester.pumpAndSettle();
      expect(find.text('Tag 2'), findsOneWidget);
      expect(find.text('Am 21.10.2026'), findsOneWidget);
      await tester.tap(find.text('Heute'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('date-2026-10-23')));
      await tester.pumpAndSettle();
      expect(find.text('Bis zur nächsten Periode'), findsOneWidget);
      expect(find.text('Noch offen'), findsOneWidget);
      expect(storage.value, before);
    },
  );

  testWidgets(
    'Speichern und Rückkehr zu Home aktualisieren den Tageszähler sofort',
    (tester) async {
      await openHome(tester);
      await tester.tap(find.byKey(const ValueKey('period-status-ring')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('period-start-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('20').last);
      final dialog = find.byType(DatePickerDialog);
      await tester.tap(
        find.text(
          MaterialLocalizations.of(tester.element(dialog)).okButtonLabel,
        ),
      );
      await tester.pumpAndSettle();
      final ongoing = find.byKey(const ValueKey('period-ongoing-switch'));
      await tester.ensureVisible(ongoing);
      await tester.tap(ongoing);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('period-save-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Zurück'));
      await tester.pumpAndSettle();
      expect(find.text('Tag 3'), findsOneWidget);
    },
  );

  testWidgets(
    'Korrektur und Löschen werden nach Rückkehr auch im Kreis übernommen',
    (tester) async {
      final storage = savedPeriod(ongoing: true);
      await openHome(tester, storage: storage);
      await tester.tap(find.byKey(const ValueKey('home-nav-Cycle')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Edit cycle data'));
      await tester.tap(find.text('Edit cycle data'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Korrigieren'));
      await tester.tap(find.text('Korrigieren'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('period-start-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('21').last);
      final dialog = find.byType(DatePickerDialog);
      await tester.tap(
        find.text(
          MaterialLocalizations.of(tester.element(dialog)).okButtonLabel,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('period-save-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Zurück'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('home-nav-Home')));
      await tester.pumpAndSettle();
      expect(find.text('Tag 2'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('home-nav-Cycle')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Edit cycle data'));
      await tester.tap(find.text('Edit cycle data'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Löschen'));
      await tester.tap(find.text('Löschen'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Löschen'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Zurück'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('home-nav-Home')));
      await tester.pumpAndSettle();
      expect(find.text('Kein Eintrag'), findsOneWidget);
      expect(storage.value, isNull);
    },
  );

  testWidgets(
    'Lesefehler zeigt keine falsche Nullanzeige und lässt sich erneut laden',
    (tester) async {
      final storage = savedPeriod(ongoing: true)..failRead = true;
      await openHome(tester, storage: storage);
      expect(find.text('Nicht verfügbar'), findsOneWidget);
      expect(find.text('Kein Eintrag'), findsNothing);
      storage.failRead = false;
      await tester.tap(find.byKey(const ValueKey('period-status-ring')));
      await tester.pumpAndSettle();
      expect(find.text('Tag 3'), findsOneWidget);
    },
  );

  testWidgets('Heute und Tageszähler wechseln bei Mitternacht automatisch', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 22, 23, 59, 59);
    await openHome(
      tester,
      storage: savedPeriod(ongoing: true),
      clock: () => now,
    );
    expect(find.text('Tag 3'), findsOneWidget);
    now = DateTime(2026, 10, 23);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Tag 4'), findsOneWidget);
    expect(find.text('Heute'), findsNWidgets(2));
  });

  testWidgets('Persönlicher Kreis passt auf Handy und breite Webansicht', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    for (final size in [
      const Size(320, 568),
      const Size(900, 700),
      const Size(1440, 1000),
    ]) {
      tester.view.physicalSize = size;
      await openHome(
        tester,
        storage: savedPeriod(start: '2026-10-03', end: '2026-10-07'),
      );
      expect(find.text('Noch offen'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'Countdown nutzt gespeicherte Beginne und erklärt seine persönliche Datenbasis',
    (tester) async {
      final storage = MemoryPeriodStorage(
        jsonEncode({
          'version': 2,
          'periods': [
            {'id': 'a', 'start': '2026-08-25', 'end': '2026-08-29'},
            {'id': 'b', 'start': '2026-09-22', 'end': '2026-09-26'},
            {'id': 'c', 'start': '2026-10-20', 'end': '2026-10-21'},
          ],
        }),
      );
      final before = storage.value;
      await openHome(tester, storage: storage);
      expect(find.text('Noch ca. 26 Tage'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('period-status-ring')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          'Median aus den letzten 2 Start-zu-Start-Abständen',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('17.11.2026'), findsOneWidget);
      expect(storage.value, before);
    },
  );
}
