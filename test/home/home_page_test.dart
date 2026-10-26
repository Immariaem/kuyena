import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuyena_tracker/main.dart';
import 'package:kuyena_tracker/periods/application/period_diary.dart';
import 'package:kuyena_tracker/periods/data/local_period_repository.dart';
import 'package:kuyena_tracker/periods/presentation/period_entry_dialog.dart';

import '../support/memory_period_storage.dart';

Future<MemoryPeriodStorage> openHome(WidgetTester tester) async {
  final storage = MemoryPeriodStorage();
  await tester.pumpWidget(
    ZyklusApp(
      key: UniqueKey(),
      diary: PeriodDiary(
        repository: LocalPeriodRepository(storage),
        clock: () => DateTime(2026, 10, 22),
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
    expect(find.text('3 Days'), findsOneWidget);
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

  testWidgets('Plus öffnet Erfassung; Abbrechen erzeugt keinen Eintrag', (
    tester,
  ) async {
    final storage = await openHome(tester);
    await tester.tap(find.byKey(const ValueKey('home-log-button')));
    await tester.pumpAndSettle();
    expect(find.byType(PeriodEntryDialog), findsOneWidget);
    expect(find.text('Ende (optional)'), findsOneWidget);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(storage.value, isNull);
    expect(find.textContaining('Noch keine Einträge.'), findsOneWidget);
  });

  testWidgets('Plus wartet bei Lesefehler mit der Erfassung', (tester) async {
    final storage = await openHome(tester);
    storage.failRead = true;
    await tester.tap(find.byKey(const ValueKey('home-log-button')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsNothing);
    expect(
      find.textContaining('Deine Einträge konnten nicht geladen werden.'),
      findsOneWidget,
    );
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
      expect(
        find.textContaining('keine persönlichen Empfehlungen'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Verstanden'));
      await tester.tap(find.text('Verstanden'));
      await tester.pumpAndSettle();
      expect(find.text('Verstanden'), findsNothing);
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
}
