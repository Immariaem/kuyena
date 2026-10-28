import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app/presentation/kuyena_shell.dart';
import 'journal/application/day_journal.dart';
import 'journal/data/local_journal_repository.dart';
import 'periods/application/period_diary.dart';
import 'periods/data/local_period_repository.dart';
import 'periods/data/secure_period_storage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ZyklusApp(
      showSplash: true,
      diary: PeriodDiary(
        repository: const LocalPeriodRepository(SecurePeriodStorage()),
      ),
    ),
  );
}

class ZyklusApp extends StatelessWidget {
  const ZyklusApp({
    super.key,
    required this.diary,
    this.journal,
    this.showSplash = false,
  });
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE58BA5)),
        useMaterial3: true,
      ),
      home: KuyenaShell(
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
      ),
    );
  }
}
