import 'profile/application/profile_controller.dart';
import 'profile/presentation/profile_gate.dart';
import 'data/storage/local_app_store.dart';
import 'data/storage/platform_data_lock.dart';
import 'data/application/data_backup_service.dart';
import 'data/backup/backup_files.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app/presentation/kuyena_shell.dart';
import 'app/presentation/browser_app_viewport.dart';
import 'journal/application/day_journal.dart';
import 'journal/data/local_journal_repository.dart';
import 'periods/application/period_diary.dart';
import 'periods/data/local_period_repository.dart';
import 'periods/data/secure_period_storage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final store = LocalAppStore(
    storage: const SecurePeriodStorage(documentKey: 'kuyena.local_data.v1'),
    legacyPeriods: const SecurePeriodStorage(),
    legacyJournal: const SecurePeriodStorage(
      documentKey: 'kuyena.day_journal.v1',
    ),
    lock: createDataLock(),
  );
  final diary = PeriodDiary(
    repository: LocalPeriodRepository(store.periodStorage),
    dataLock: store.lock,
  );
  final journal = DayJournal(
    repository: LocalJournalRepository(store.journalStorage),
    dataLock: store.lock,
    clock: diary.clock,
  );
  runApp(
    ZyklusApp(
      showSplash: true,
      profileController: ProfileController(
        store: store,
        today: () => diary.today,
      ),
      diary: diary,
      journal: journal,
      backupService: DataBackupService(store: store, today: () => diary.today),
    ),
  );
}

class ZyklusApp extends StatelessWidget {
  const ZyklusApp({
    super.key,
    required this.diary,
    this.journal,
    this.showSplash = false,
    this.backupService,
    this.backupFiles,
    this.profileController,
  });
  final DataBackupService? backupService;
  final BackupFiles? backupFiles;
  final ProfileController? profileController;
  final DayJournal? journal;
  final bool showSplash;
  final PeriodDiary diary;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kuyena',
      locale: const Locale('de'),
      supportedLocales: const [Locale('de')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) =>
          BrowserAppViewport(child: child ?? const SizedBox.shrink()),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE58BA5)),
        useMaterial3: true,
      ),
      home: profileController == null
          ? _shell()
          : ProfileGate(
              controller: profileController!,
              backupService: backupService,
              backupFiles: backupFiles,
              child: _shell(),
            ),
    );
  }

  Widget _shell() => KuyenaShell(
    diary: diary,
    journal:
        journal ??
        DayJournal(
          repository: const LocalJournalRepository(
            SecurePeriodStorage(documentKey: 'kuyena.day_journal.v1'),
          ),
          clock: diary.clock,
        ),
    showSplash: showSplash,
    backupService: backupService,
    backupFiles: backupFiles,
    profileController: profileController,
  );
}
