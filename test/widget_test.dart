import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuyena_tracker/main.dart';
import 'package:kuyena_tracker/periods/application/period_diary.dart';
import 'package:kuyena_tracker/periods/data/local_period_repository.dart';
import 'package:kuyena_tracker/periods/presentation/period_entry_dialog.dart';

import 'support/memory_period_storage.dart';

Future<void> openDiary(WidgetTester tester, MemoryPeriodStorage storage) async {
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  await tester.pumpWidget(
    ZyklusApp(
      key: UniqueKey(),
      diary: PeriodDiary(
        repository: LocalPeriodRepository(storage),
        clock: () => DateTime(2026, 10, 18),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('home-nav-Calendar')));
  await tester.pumpAndSettle();
}

Future<void> openEntry(WidgetTester tester) async {
  final add = find.text('Periode eintragen');
  await tester.ensureVisible(add);
  await tester.tap(add);
  await tester.pumpAndSettle();
}

Future<void> pickDate(WidgetTester tester, String field, {String? day}) async {
  final button = find.byKey(ValueKey(field));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
  if (day != null) {
    await tester.tap(find.text(day).last);
    await tester.pumpAndSettle();
  }
  final dialog = find.byType(DatePickerDialog);
  final label = MaterialLocalizations.of(tester.element(dialog)).okButtonLabel;
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> saveEntry(WidgetTester tester) async {
  final save = find.byKey(const ValueKey('period-save-button'));
  await tester.ensureVisible(save);
  await tester.tap(save);
  await tester.pumpAndSettle();
}

Future<void> addDate(WidgetTester tester, {String? day}) async {
  await openEntry(tester);
  if (day != null) await pickDate(tester, 'period-start-field', day: day);
  await saveEntry(tester);
}

void main() {
  testWidgets('Leerer Verlauf bietet die Datumserfassung an', (tester) async {
    await openDiary(tester, MemoryPeriodStorage());
    expect(find.text('Dein Zyklus. Dein Überblick.'), findsOneWidget);
    expect(find.textContaining('Noch keine Einträge.'), findsOneWidget);
    expect(find.text('Periode eintragen'), findsOneWidget);
  });

  testWidgets('Bestätigtes Datum bleibt nach Neuaufbau der App erhalten', (
    tester,
  ) async {
    final storage = MemoryPeriodStorage();
    await openDiary(tester, storage);
    await addDate(tester);
    expect(find.text('Periodenbeginn: 18.10.2026'), findsOneWidget);
    await openDiary(tester, storage);
    expect(find.text('Periodenbeginn: 18.10.2026'), findsOneWidget);
  });

  testWidgets('Korrektur ändert das Datum, abgebrochenes Löschen erhält es', (
    tester,
  ) async {
    final storage = MemoryPeriodStorage();
    await openDiary(tester, storage);
    await addDate(tester);
    await tester.ensureVisible(find.text('Korrigieren'));
    await tester.tap(find.text('Korrigieren'));
    await tester.pumpAndSettle();
    await pickDate(tester, 'period-start-field', day: '1');
    await saveEntry(tester);
    expect(find.text('Periodenbeginn: 01.10.2026'), findsOneWidget);
    expect(find.text('Periodenbeginn: 18.10.2026'), findsNothing);

    await tester.ensureVisible(find.text('Löschen'));
    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(find.text('Periodenbeginn: 01.10.2026'), findsOneWidget);
  });

  testWidgets(
    'Löschen erfordert Bestätigung und bleibt nach erneutem Laden wirksam',
    (tester) async {
      final storage = MemoryPeriodStorage();
      await openDiary(tester, storage);
      await addDate(tester);
      await tester.ensureVisible(find.text('Löschen'));
      await tester.tap(find.text('Löschen'));
      await tester.pumpAndSettle();
      final confirm = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Löschen'),
      );
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      await openDiary(tester, storage);
      expect(find.textContaining('Noch keine Einträge.'), findsOneWidget);
      expect(storage.value, isNull);
    },
  );

  testWidgets(
    'Speicherfehler erzeugt keine Erfolgsmeldung und keinen neuen Eintrag',
    (tester) async {
      final storage = MemoryPeriodStorage()..failWrite = true;
      await openDiary(tester, storage);
      await addDate(tester);
      expect(
        find.textContaining('Die Änderung konnte nicht bestätigt werden.'),
        findsOneWidget,
      );
      expect(find.text('Periode gespeichert.'), findsNothing);
      expect(find.text('Periodenbeginn: 18.10.2026'), findsNothing);
      expect(storage.value, isNull);
      expect(find.byType(PeriodEntryDialog), findsOneWidget);
      expect(find.text('18.10.2026'), findsOneWidget);
      storage.failWrite = false;
      await saveEntry(tester);
      expect(find.text('Periodenbeginn: 18.10.2026'), findsOneWidget);
    },
  );

  testWidgets(
    'Bei Lesefehlern werden neue Einträge bis zum erfolgreichen Laden gesperrt',
    (tester) async {
      final storage = MemoryPeriodStorage()..failRead = true;
      await openDiary(tester, storage);
      expect(
        find.textContaining('Deine Einträge konnten nicht geladen werden.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Periode eintragen'));
      await tester.tap(find.text('Periode eintragen'));
      await tester.pumpAndSettle();
      expect(find.byType(PeriodEntryDialog), findsNothing);
      storage.failRead = false;
      await tester.ensureVisible(find.text('Verlauf neu laden'));
      await tester.tap(find.text('Verlauf neu laden'));
      await tester.pumpAndSettle();
      await addDate(tester);
      expect(find.text('Periodenbeginn: 18.10.2026'), findsOneWidget);
    },
  );

  testWidgets('Kleine Handyansicht bleibt ohne Layoutfehler bedienbar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openDiary(tester, MemoryPeriodStorage());
    await openEntry(tester);
    await pickDate(tester, 'period-end-field');
    await saveEntry(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Periodenbeginn: 18.10.2026'), findsOneWidget);
  });

  testWidgets('Beginn und Ende bleiben nach erneutem Öffnen erhalten', (
    tester,
  ) async {
    final storage = MemoryPeriodStorage();
    await openDiary(tester, storage);
    await openEntry(tester);
    await pickDate(tester, 'period-start-field', day: '3');
    await pickDate(tester, 'period-end-field', day: '7');
    expect(storage.value, isNull);
    await saveEntry(tester);
    await openDiary(tester, storage);
    expect(find.text('Periodenbeginn: 03.10.2026'), findsOneWidget);
    expect(find.text('Periodenende: 07.10.2026'), findsOneWidget);
  });

  testWidgets(
    'Bei einem alten Eintrag kann ein Ende ergänzt und wieder entfernt werden',
    (tester) async {
      final storage = MemoryPeriodStorage(
        '{"version":1,"starts":["2026-10-03"]}',
      );
      await openDiary(tester, storage);
      final id = (await LocalPeriodRepository(storage).load()).single.id;
      expect(find.text('Periodenende: unbekannt'), findsOneWidget);
      await tester.ensureVisible(find.text('Korrigieren'));
      await tester.tap(find.text('Korrigieren'));
      await tester.pumpAndSettle();
      await pickDate(tester, 'period-end-field', day: '7');
      await saveEntry(tester);
      expect((await LocalPeriodRepository(storage).load()).single.id, id);
      await tester.ensureVisible(find.text('Korrigieren'));
      await tester.tap(find.text('Korrigieren'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('period-remove-end')));
      await tester.pumpAndSettle();
      await saveEntry(tester);
      await openDiary(tester, storage);
      expect(find.text('Periodenende: unbekannt'), findsOneWidget);
      expect((await LocalPeriodRepository(storage).load()).single.id, id);
    },
  );

  testWidgets(
    'Abbrechen nach der Endauswahl erhält den gespeicherten Eintrag',
    (tester) async {
      const raw = '{"version":1,"starts":["2026-10-03"]}';
      final storage = MemoryPeriodStorage(raw);
      await openDiary(tester, storage);
      await tester.ensureVisible(find.text('Korrigieren'));
      await tester.tap(find.text('Korrigieren'));
      await tester.pumpAndSettle();
      await pickDate(tester, 'period-end-field', day: '7');
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      expect(storage.value, raw);
      expect(find.text('Periodenende: unbekannt'), findsOneWidget);
    },
  );

  testWidgets('Ungültige Korrektur bleibt zum Verbessern geöffnet', (
    tester,
  ) async {
    final storage = MemoryPeriodStorage(
      '{"version":2,"periods":[{"id":"alt","start":"2026-10-03","end":"2026-10-07"}]}',
    );
    final before = storage.value;
    await openDiary(tester, storage);
    await tester.ensureVisible(find.text('Korrigieren'));
    await tester.tap(find.text('Korrigieren'));
    await tester.pumpAndSettle();
    await pickDate(tester, 'period-start-field', day: '8');
    await saveEntry(tester);
    expect(
      find.text('Das Periodenende darf nicht vor dem Beginn liegen.'),
      findsOneWidget,
    );
    expect(storage.value, before);
    expect(find.byType(PeriodEntryDialog), findsOneWidget);
    expect(find.text('07.10.2026'), findsOneWidget);
    await pickDate(tester, 'period-start-field', day: '2');
    await saveEntry(tester);
    expect(find.text('Periodenbeginn: 02.10.2026'), findsOneWidget);
    expect(find.text('Periodenende: 07.10.2026'), findsOneWidget);
  });

  testWidgets(
    'Laufende Periode wird ausdrücklich gespeichert und durch ein Ende beendet',
    (tester) async {
      final storage = MemoryPeriodStorage();
      await openDiary(tester, storage);
      await openEntry(tester);
      final ongoing = find.byKey(const ValueKey('period-ongoing-switch'));
      await tester.ensureVisible(ongoing);
      await tester.tap(ongoing);
      await tester.pumpAndSettle();
      await saveEntry(tester);
      expect(
        (await LocalPeriodRepository(storage).load()).single.isOngoing,
        isTrue,
      );
      await openDiary(tester, storage);
      expect(find.text('Periode läuft noch'), findsOneWidget);
      await tester.ensureVisible(find.text('Korrigieren'));
      await tester.tap(find.text('Korrigieren'));
      await tester.pumpAndSettle();
      await pickDate(tester, 'period-end-field');
      await saveEntry(tester);
      final period = (await LocalPeriodRepository(storage).load()).single;
      expect(period.isOngoing, isFalse);
      expect(period.end, isNotNull);
      expect(find.text('Periodenende: 18.10.2026'), findsOneWidget);
    },
  );
}
