import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuyena_tracker/app/presentation/browser_app_viewport.dart';
import 'package:kuyena_tracker/journal/application/day_journal.dart';
import 'package:kuyena_tracker/journal/data/local_journal_repository.dart';
import 'package:kuyena_tracker/main.dart';
import 'package:kuyena_tracker/periods/application/period_diary.dart';
import 'package:kuyena_tracker/periods/data/local_period_repository.dart';

import '../support/memory_period_storage.dart';

void wideWindow(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1440, 1000);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
}

void main() {
  testWidgets('Browser starts in phone view; native layout keeps its width', (
    tester,
  ) async {
    wideWindow(tester);
    final periods = MemoryPeriodStorage();
    final days = MemoryPeriodStorage();
    Widget app() => ZyklusApp(
      key: UniqueKey(),
      diary: PeriodDiary(
        repository: LocalPeriodRepository(periods),
        clock: () => DateTime(2026, 10, 30),
      ),
      journal: DayJournal(
        repository: LocalJournalRepository(days),
        clock: () => DateTime(2026, 10, 30),
      ),
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Hallo'), findsOneWidget);
    if (kIsWeb) {
      expect(find.byKey(const ValueKey('desktop-home')), findsNothing);
      await tester.tap(find.text('Desktopansicht'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('desktop-home')), findsOneWidget);
      await tester.tap(find.text('Handyansicht'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('desktop-home')), findsNothing);
      await tester.tap(find.text('Desktopansicht'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('desktop-home')), findsNothing);
    } else {
      expect(find.byKey(const ValueKey('desktop-home')), findsOneWidget);
      expect(find.byKey(const ValueKey('browser-view-toggle')), findsNothing);
    }
    expect(periods.value, isNull);
    expect(days.value, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Changing view and window size preserves an open form and route',
    (tester) async {
      wideWindow(tester);
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) =>
                BrowserAppViewport(enabled: true, child: child!),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const _DraftPage()),
                  ),
                  child: const Text('Eintrag öffnen'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Eintrag öffnen'));
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('Desktopansicht'), findsOneWidget);
        final draft = find.byKey(const ValueKey('draft'));
        await tester.enterText(draft, 'Meine offene Notiz');
        expect(MediaQuery.sizeOf(tester.element(draft)).width, 412);
        await tester.tap(find.text('Desktopansicht'));
        await tester.pumpAndSettle();
        expect(find.text('Meine offene Notiz'), findsOneWidget);
        expect(MediaQuery.sizeOf(tester.element(draft)).width, 1440);
        await tester.tap(find.text('Handyansicht'));
        await tester.pumpAndSettle();
        tester.view.physicalSize = const Size(320, 568);
        await tester.pumpAndSettle();
        expect(find.text('Meine offene Notiz'), findsOneWidget);
        expect(MediaQuery.sizeOf(tester.element(draft)).width, 320);
        expect(find.byKey(const ValueKey('browser-view-toggle')), findsNothing);
        tester.view.physicalSize = const Size(1440, 1000);
        await tester.pumpAndSettle();
        expect(find.text('Meine offene Notiz'), findsOneWidget);
        expect(MediaQuery.sizeOf(tester.element(draft)).width, 412);
        await tester.tap(find.text('Dialog öffnen'));
        await tester.pumpAndSettle();
        final dialog = find.byType(AlertDialog);
        expect(find.bySemanticsLabel('Desktopansicht'), findsOneWidget);
        expect(tester.getSize(dialog).width, lessThanOrEqualTo(412));
        expect(MediaQuery.sizeOf(tester.element(dialog)).width, 412);
        await tester.tap(find.text('Schließen'));
        await tester.pumpAndSettle();
        expect(find.text('Meine offene Notiz'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );
}

class _DraftPage extends StatelessWidget {
  const _DraftPage();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Eintrag')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const TextField(key: ValueKey('draft')),
        TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Testdialog'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Schließen'),
                ),
              ],
            ),
          ),
          child: const Text('Dialog öffnen'),
        ),
      ],
    ),
  );
}
