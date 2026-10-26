import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'home/presentation/kuyena_home_page.dart';
import 'periods/application/period_diary.dart';
import 'periods/data/local_period_repository.dart';
import 'periods/data/secure_period_storage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ZyklusApp(
      diary: PeriodDiary(
        repository: const LocalPeriodRepository(SecurePeriodStorage()),
      ),
    ),
  );
}

class ZyklusApp extends StatelessWidget {
  const ZyklusApp({super.key, required this.diary});
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
      home: KuyenaHomePage(diary: diary),
    );
  }
}
