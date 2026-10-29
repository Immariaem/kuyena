import 'dart:typed_data';
import 'package:kuyena_tracker/data/backup/encrypted_backup.dart';
import 'package:kuyena_tracker/data/backup/backup_files.dart';
import 'package:kuyena_tracker/data/backup/backup_document.dart';
import 'package:kuyena_tracker/data/application/data_backup_service.dart';
import 'package:kuyena_tracker/data/storage/local_app_store.dart';
import 'package:kuyena_tracker/data/storage/data_lock.dart';
import 'package:kuyena_tracker/journal/application/day_journal.dart';
import 'package:kuyena_tracker/journal/data/local_journal_repository.dart';
import 'package:kuyena_tracker/periods/application/period_diary.dart';
import 'package:kuyena_tracker/periods/data/local_period_repository.dart';
import 'package:kuyena_tracker/periods/domain/calendar_date.dart';
import '../support/memory_period_storage.dart';

final dataToday = CalendarDate(2026, 10, 29);

class DataFixture {
  DataFixture() {
    store = LocalAppStore(
      storage: storage,
      legacyPeriods: legacyPeriods,
      legacyJournal: legacyJournal,
      lock: lock,
    );
    diary = PeriodDiary(
      repository: LocalPeriodRepository(store.periodStorage),
      dataLock: lock,
      clock: () => dataToday.value,
    );
    journal = DayJournal(
      repository: LocalJournalRepository(store.journalStorage),
      dataLock: lock,
      clock: () => dataToday.value,
    );
  }
  final storage = MemoryPeriodStorage(),
      legacyPeriods = MemoryPeriodStorage(),
      legacyJournal = MemoryPeriodStorage();
  final lock = DataLock();
  late final LocalAppStore store;
  late final PeriodDiary diary;
  late final DayJournal journal;
  DataBackupService service({EncryptedBackup? encryption}) => DataBackupService(
    store: store,
    today: () => dataToday,
    encryption: encryption,
  );
}

class TestBackupFiles extends BackupFiles {
  Uint8List? picked, saved;
  String? filename;
  bool failSave = false, cancelSave = false;
  @override
  Future<Uint8List?> pick() async => picked;
  @override
  Future<bool> save(String name, Uint8List bytes) async {
    if (failSave) throw StateError('Test failure');
    if (cancelSave) return false;
    filename = name;
    saved = bytes;
    return true;
  }
}

class TestEncryption extends EncryptedBackup {
  @override
  Future<Uint8List> encrypt(String plaintext, String password) async {
    EncryptedBackup.validatePassword(password);
    return Uint8List.fromList([1, 2, 3, 4]);
  }

  @override
  Future<String> decrypt(Uint8List bytes, String password) async =>
      throw const BackupException('Test password failure');
}
