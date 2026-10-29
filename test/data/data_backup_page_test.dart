import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuyena_tracker/main.dart';
import 'package:kuyena_tracker/data/backup/backup_document.dart';
import 'package:kuyena_tracker/data/presentation/data_backup_page.dart';
import 'package:kuyena_tracker/journal/domain/day_entry.dart';
import 'package:kuyena_tracker/periods/domain/period.dart';
import '../app/seven_screens_test.dart' show tapKey, tapText, go, openForm;
import 'data_fixture.dart';

Future<void> openDataApp(
  WidgetTester t,
  DataFixture f,
  TestBackupFiles files,
) async {
  addTearDown(() => t.pumpWidget(const SizedBox.shrink()));
  await t.pumpWidget(
    ZyklusApp(
      key: UniqueKey(),
      diary: f.diary,
      journal: f.journal,
      backupService: f.service(encryption: TestEncryption()),
      backupFiles: files,
    ),
  );
  await t.pumpAndSettle();
}

Uint8List sampleBackup() => Uint8List.fromList(
  utf8.encode(
    BackupDocument(
      periods: [
        Period(id: 'restored', start: dataToday.addDays(-2), end: dataToday),
      ],
      journal: JournalData(
        entries: [
          DayEntry(
            date: dataToday,
            symptoms: {Symptom.fatigue},
            energy: 0,
            note: 'Restored',
          ),
        ],
        reminders: true,
        periodDays: {dataToday.addDays(-1): false},
      ),
    ).encode(),
  ),
);
Future<void> openBackup(WidgetTester t) async {
  await go(t, 'Cycle');
  await tapText(t, 'Sicherung & Wiederherstellung');
}

void main() {
  testWidgets(
    'Backup screen is reachable without entries and cancelling file selection changes nothing',
    (t) async {
      final f = DataFixture(), files = TestBackupFiles();
      await openDataApp(t, f, files);
      await openBackup(t);
      expect(find.byType(DataBackupPage), findsOneWidget);
      expect(find.text('Sichern und wiederherstellen'), findsOneWidget);
      await tapKey(t, 'pick-backup-file');
      expect(find.byKey(const ValueKey('check-backup')), findsNothing);
      expect(f.storage.value, isNull);
    },
  );
  testWidgets(
    'Password validation and encrypted file saving support failure, cancellation and retry',
    (t) async {
      final f = DataFixture(), files = TestBackupFiles();
      await f.journal.saveWellbeing(DayEntry(date: dataToday, note: 'Keep'));
      await openDataApp(t, f, files);
      await openBackup(t);
      await tapKey(t, 'create-backup');
      await t.enterText(find.byKey(const ValueKey('backup-password')), 'short');
      await tapKey(t, 'prepare-backup');
      expect(find.textContaining('mindestens 12 Zeichen'), findsWidgets);
      expect(files.saved, isNull);
      await t.enterText(
        find.byKey(const ValueKey('backup-password')),
        'my test long passphrase',
      );
      await t.enterText(
        find.byKey(const ValueKey('backup-repeat')),
        'different',
      );
      await tapKey(t, 'prepare-backup');
      expect(find.textContaining('nicht überein'), findsOneWidget);
      await t.enterText(
        find.byKey(const ValueKey('backup-repeat')),
        'my test long passphrase',
      );
      await tapKey(t, 'prepare-backup');
      expect(find.byKey(const ValueKey('backup-password')), findsNothing);
      files.failSave = true;
      await tapKey(t, 'save-backup-file');
      expect(find.textContaining('nicht bestätigt'), findsOneWidget);
      files.failSave = false;
      files.cancelSave = true;
      await tapKey(t, 'save-backup-file');
      expect(find.textContaining('Speichern abgebrochen'), findsOneWidget);
      files.cancelSave = false;
      await tapKey(t, 'save-backup-file');
      expect(files.saved, [1, 2, 3, 4]);
      expect(files.filename, 'kuyena-backup-2026-10-29.kuyena');
      expect((await f.journal.load()).entryFor(dataToday)!.note, 'Keep');
    },
  );
  testWidgets(
    'Restore previews the whole file, cancellation preserves data, confirmation updates Home',
    (t) async {
      final f = DataFixture(),
          files = TestBackupFiles()..picked = sampleBackup();
      await f.journal.saveWellbeing(DayEntry(date: dataToday, note: 'Current'));
      await openDataApp(t, f, files);
      await openBackup(t);
      final before = f.storage.value;
      await tapKey(t, 'pick-backup-file');
      await tapKey(t, 'check-backup');
      expect(find.text('Sicherung geprüft'), findsOneWidget);
      expect(f.storage.value, before);
      await tapKey(t, 'restore-backup');
      await tapText(t, 'Abbrechen');
      expect(f.storage.value, before);
      await tapKey(t, 'restore-backup');
      await tapKey(t, 'confirm-restore');
      expect(find.byType(DataBackupPage), findsNothing);
      final data = await f.store.load();
      expect(data.periods.single.id, 'restored');
      expect(data.journal.entries.single.note, 'Restored');
      expect(data.journal.reminders, isTrue);
      await go(t, 'Home');
      expect(find.text('Tag 3'), findsOneWidget);
      expect(find.text('Logged symptoms'), findsOneWidget);
    },
  );
  testWidgets(
    'Invalid file and wrong password leave all current data untouched',
    (t) async {
      final f = DataFixture(),
          files = TestBackupFiles()
            ..picked = Uint8List.fromList(utf8.encode('bad file'));
      await f.journal.saveWellbeing(DayEntry(date: dataToday, note: 'Current'));
      await openDataApp(t, f, files);
      await openBackup(t);
      final before = f.storage.value;
      await tapKey(t, 'pick-backup-file');
      await tapKey(t, 'check-backup');
      expect(find.textContaining('keine gültige'), findsOneWidget);
      expect(f.storage.value, before);
      files.picked = Uint8List.fromList(
        utf8.encode('{"format":"kuyena-backup"}'),
      );
      await tapKey(t, 'pick-backup-file');
      await t.enterText(
        find.byKey(const ValueKey('restore-password')),
        'wrong',
      );
      await tapKey(t, 'check-backup');
      expect(find.text('Test password failure'), findsOneWidget);
      expect(f.storage.value, before);
      expect(find.byKey(const ValueKey('restore-backup')), findsNothing);
    },
  );
  testWidgets(
    'Failed restore keeps current data and supports retry; stale review cannot overwrite new entries',
    (t) async {
      final f = DataFixture(),
          files = TestBackupFiles()..picked = sampleBackup();
      await openDataApp(t, f, files);
      await openBackup(t);
      await tapKey(t, 'pick-backup-file');
      await tapKey(t, 'check-backup');
      await f.journal.saveWellbeing(DayEntry(date: dataToday, note: 'Newer'));
      final before = f.storage.value;
      await tapKey(t, 'restore-backup');
      await tapKey(t, 'confirm-restore');
      expect(find.textContaining('inzwischen geändert'), findsOneWidget);
      expect(f.storage.value, before);
      await tapKey(t, 'check-backup');
      f.storage.failWrite = true;
      await tapKey(t, 'restore-backup');
      await tapKey(t, 'confirm-restore');
      expect(f.storage.value, before);
      expect(find.byType(DataBackupPage), findsOneWidget);
      f.storage.failWrite = false;
      await tapKey(t, 'restore-backup');
      await tapKey(t, 'confirm-restore');
      expect((await f.journal.load()).entryFor(dataToday)!.note, 'Restored');
    },
  );
  testWidgets(
    'Corrupt storage exposes recovery and explicit clear removes both sections',
    (t) async {
      final f = DataFixture(),
          files = TestBackupFiles()..picked = sampleBackup();
      f.storage.value = 'broken';
      await openDataApp(t, f, files);
      await go(t, 'Cycle');
      await tapText(t, 'Sicherung wiederherstellen');
      await tapKey(t, 'pick-backup-file');
      await tapKey(t, 'check-backup');
      await tapKey(t, 'restore-backup');
      await tapKey(t, 'confirm-restore');
      await tapText(t, 'Delete all local data');
      await tapText(t, 'Delete all');
      final data = await f.store.load();
      expect(data.periods, isEmpty);
      expect(data.journal.entries, isEmpty);
      expect(data.journal.periodDays, isEmpty);
      expect(data.journal.reminders, isFalse);
    },
  );
  testWidgets(
    'A stale wellbeing form keeps its draft instead of replacing newer symptoms',
    (t) async {
      final f = DataFixture(), files = TestBackupFiles();
      await f.journal.saveWellbeing(
        DayEntry(date: dataToday, note: 'Original'),
      );
      await openDataApp(t, f, files);
      await openForm(t);
      await t.enterText(find.byKey(const ValueKey('day-note')), 'Draft');
      await f.journal.saveWellbeing(
        DayEntry(date: dataToday, symptoms: {Symptom.headache}, note: 'Newer'),
      );
      await tapKey(t, 'save-day-entry');
      expect(find.textContaining('inzwischen geändert'), findsOneWidget);
      expect(
        t
            .widget<TextField>(find.byKey(const ValueKey('day-note')))
            .controller!
            .text,
        'Draft',
      );
      expect((await f.journal.load()).entryFor(dataToday)!.note, 'Newer');
    },
  );
  for (final width in [320.0, 412.0, 1024.0, 1440.0]) {
    testWidgets('Backup controls fit width $width and larger text', (t) async {
      t.view.physicalSize = Size(width, 850);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final f = DataFixture(), files = TestBackupFiles();
      await t.pumpWidget(
        MaterialApp(
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(
              c,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: DataBackupPage(
            service: f.service(encryption: TestEncryption()),
            files: files,
          ),
        ),
      );
      await t.pumpAndSettle();
      await tapKey(t, 'create-backup');
      expect(t.takeException(), isNull);
      await t.ensureVisible(find.byKey(const ValueKey('prepare-backup')));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  }
}
