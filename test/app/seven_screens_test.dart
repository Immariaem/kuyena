import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuyena_tracker/main.dart';
import 'package:kuyena_tracker/app/presentation/kuyena_splash.dart';
import 'package:kuyena_tracker/journal/application/day_journal.dart';
import 'package:kuyena_tracker/journal/data/local_journal_repository.dart';
import 'package:kuyena_tracker/journal/domain/day_entry.dart';
import 'package:kuyena_tracker/periods/application/period_diary.dart';
import 'package:kuyena_tracker/periods/data/local_period_repository.dart';
import 'package:kuyena_tracker/periods/domain/calendar_date.dart';
import '../support/memory_period_storage.dart';

final today = CalendarDate(2026, 10, 19);
Future<void> openApp(
  WidgetTester tester, {
  MemoryPeriodStorage? periods,
  MemoryPeriodStorage? days,
  bool splash = false,
  CalendarDate? currentDay,
}) async {
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  await tester.pumpWidget(
    ZyklusApp(
      key: UniqueKey(),
      diary: PeriodDiary(
        repository: LocalPeriodRepository(periods ?? MemoryPeriodStorage()),
        clock: () => (currentDay ?? today).value,
      ),
      journal: DayJournal(
        repository: LocalJournalRepository(days ?? MemoryPeriodStorage()),
        clock: () => (currentDay ?? today).value,
      ),
      showSplash: splash,
    ),
  );
  if (!splash) await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester t, String key) async {
  final f = find.byKey(ValueKey(key));
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<void> tapText(WidgetTester t, String text) async {
  final f = find.text(text).last;
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<void> go(WidgetTester t, String label) => tapKey(t, 'home-nav-$label');
Future<void> openForm(WidgetTester t) async {
  await tapKey(t, 'home-log-button');
  await tapText(t, 'Continue');
}

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.getData') return {'text': 'export'};
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );
  testWidgets('Splash uses the six original logo assets then opens Home', (
    t,
  ) async {
    await openApp(t, splash: true);
    await t.pump();
    expect(find.byType(KuyenaSplash), findsOneWidget);
    await t.pump(const Duration(milliseconds: 1500));
    await t.pumpAndSettle();
    expect(find.text('Hey, girl!'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('Calendar opens its menu and switches Day, Month and Year', (
    t,
  ) async {
    await openApp(t);
    await go(t, 'Calendar');
    expect(find.text('October 2026'), findsWidgets);
    await tapKey(t, 'calendar-view-selector');
    expect(find.text('Day'), findsOneWidget);
    expect(find.text('Year'), findsOneWidget);
    await tapText(t, 'Year');
    expect(find.byKey(const ValueKey('year-month-12')), findsOneWidget);
    await tapKey(t, 'year-month-10');
    await tapKey(t, 'calendar-2026-10-19');
    expect(find.text('No day entry yet.'), findsOneWidget);
    await tapText(t, 'Log this day');
    expect(find.text('Choose a date'), findsOneWidget);
  });
  testWidgets(
    'Date picker handles month boundaries and disallows future dates',
    (t) async {
      await openApp(t);
      await tapKey(t, 'home-log-button');
      await t.tap(find.byTooltip('Previous month'));
      await t.pumpAndSettle();
      await tapKey(t, 'pick-2026-09-30');
      await tapText(t, 'Continue');
      expect(find.text('Wednesday, 30 September 2026'), findsOneWidget);
      await tapText(t, 'Back to date');
      await t.tap(find.byTooltip('Next month'));
      await t.pumpAndSettle();
      await tapKey(t, 'pick-2026-10-20');
      await tapText(t, 'Continue');
      expect(find.text('Wednesday, 30 September 2026'), findsOneWidget);
    },
  );
  testWidgets('Daily observations save and reopen without creating a period', (
    t,
  ) async {
    final days = MemoryPeriodStorage(), periods = MemoryPeriodStorage();
    await openApp(t, days: days, periods: periods);
    await openForm(t);
    await tapKey(t, 'symptom-fatigue');
    await tapKey(t, 'mood-okay');
    await t.enterText(find.byKey(const ValueKey('day-note')), 'A quiet day');
    await tapKey(t, 'save-day-entry');
    expect(find.text('Hey, girl!'), findsOneWidget);
    expect(find.text('Logged symptoms'), findsOneWidget);
    expect(find.text('Fatigue'), findsOneWidget);
    expect(periods.value, isNull);
    final data = await LocalJournalRepository(days).load();
    expect(data.entries.single.symptoms, {Symptom.fatigue});
    expect(data.entries.single.flow, isNull);
    expect(data.entries.single.energy, isNull);
    await openForm(t);
    expect(find.text('✓ Fatigue'), findsOneWidget);
    expect(find.text('✓ Okay'), findsOneWidget);
    expect(find.text('A quiet day'), findsOneWidget);
    await tapKey(t, 'symptom-cramps');
    await tapKey(t, 'save-day-entry');
    expect((await LocalJournalRepository(days).load()).entries.length, 1);
    expect(find.text('Cramps\nFatigue'), findsOneWidget);
    await openApp(t, days: days, periods: periods);
    expect(find.text('Cramps\nFatigue'), findsOneWidget);
    await go(t, 'Calendar');
    await tapKey(t, 'calendar-2026-10-19');
    expect(find.textContaining('Fatigue'), findsOneWidget);
  });
  testWidgets(
    'Failed save retains draft and discard requires an explicit choice',
    (t) async {
      final days = MemoryPeriodStorage();
      await openApp(t, days: days);
      await openForm(t);
      await tapKey(t, 'symptom-cramps');
      days.failWrite = true;
      await tapKey(t, 'save-day-entry');
      expect(find.textContaining('Your draft is still here'), findsOneWidget);
      expect(find.text('✓ Cramps'), findsOneWidget);
      await tapText(t, 'Back to date');
      expect(find.text('Discard changes?'), findsOneWidget);
      await tapText(t, 'Keep editing');
      expect(find.text('✓ Cramps'), findsOneWidget);
      await go(t, 'Calendar');
      await tapText(t, 'Discard');
      expect(find.text('Calendar'), findsWidgets);
      expect(days.value, isNull);
    },
  );
  testWidgets(
    'New day has no invented default observation; empty save is rejected',
    (t) async {
      final days = MemoryPeriodStorage();
      await openApp(t, days: days);
      await openForm(t);
      expect(find.text('✓ None'), findsNothing);
      expect(find.text('✓ Fatigue'), findsNothing);
      expect(find.text('✓ Okay'), findsNothing);
      await tapKey(t, 'save-day-entry');
      expect(find.textContaining('Choose at least one'), findsOneWidget);
      expect(days.value, isNull);
    },
  );
  testWidgets(
    'Energy slider records a chosen value and supports keyboard changes',
    (t) async {
      final days = MemoryPeriodStorage();
      await openApp(t, days: days);
      await openForm(t);
      final slider = find.byKey(const ValueKey('energy-slider'));
      await t.ensureVisible(slider);
      await t.pumpAndSettle();
      final rect = t.getRect(slider);
      await t.tapAt(Offset(rect.left + rect.width * .8, rect.center.dy));
      await t.pumpAndSettle();
      expect(find.text('High'), findsNWidgets(2));
      t.widget<Slider>(slider).focusNode!.requestFocus();
      await t.pumpAndSettle();
      final before = t.widget<Slider>(slider).value;
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.pumpAndSettle();
      expect(t.widget<Slider>(slider).value, greaterThan(before));
      await tapKey(t, 'save-day-entry');
      expect(
        (await LocalJournalRepository(days).load()).entries.single.energy,
        greaterThan(67),
      );
    },
  );
  testWidgets(
    'Deleting a day removes its own symptoms and leaves periods intact',
    (t) async {
      final days = MemoryPeriodStorage(), periods = MemoryPeriodStorage();
      await LocalJournalRepository(days).save(
        JournalData(
          entries: [
            DayEntry(date: today, symptoms: {Symptom.fatigue}),
          ],
        ),
      );
      await openApp(t, days: days, periods: periods);
      await openForm(t);
      await tapText(t, 'Delete this entry');
      await tapText(t, 'Cancel');
      expect((await LocalJournalRepository(days).load()).entries, isNotEmpty);
      await tapText(t, 'Delete this entry');
      await tapText(t, 'Delete');
      expect((await LocalJournalRepository(days).load()).entries, isEmpty);
      expect(find.text('Logged symptoms'), findsNothing);
      expect(find.text('Possible symptoms'), findsOneWidget);
      expect(periods.value, isNull);
    },
  );
  testWidgets(
    'Cycle empty state, privacy, reminder, export and deletion are connected',
    (t) async {
      final days = MemoryPeriodStorage();
      await openApp(t, days: days);
      await go(t, 'Cycle');
      expect(find.text('No periods logged yet.'), findsOneWidget);
      expect(find.text('Available after your first entry.'), findsOneWidget);
      await tapText(t, 'Privacy information');
      expect(
        find.textContaining('does not send your entries to a server'),
        findsOneWidget,
      );
      await tapText(t, 'Close');
      await tapText(t, 'About the app');
      expect(find.text('About Kuyena'), findsOneWidget);
      await tapText(t, 'Close');
      await tapText(t, 'Reminders');
      await tapText(t, 'Close');
      expect((await LocalJournalRepository(days).load()).reminders, isTrue);
      await go(t, 'Home');
      expect(find.textContaining('A moment for you?'), findsOneWidget);
      await openForm(t);
      await tapKey(t, 'mood-okay');
      await tapKey(t, 'save-day-entry');
      await go(t, 'Cycle');
      await tapText(t, 'Export data');
      expect(find.text('Copy JSON export'), findsOneWidget);
      expect(find.textContaining('kuyena-export'), findsOneWidget);
      await tapText(t, 'Copy JSON export');
      await t.pump(const Duration(milliseconds: 100));
      await t.pumpAndSettle();
      expect(find.text('Copy JSON export'), findsNothing);
      await tapText(t, 'Delete all local data');
      await tapText(t, 'Cancel');
      expect(days.value, isNotNull);
      await tapText(t, 'Delete all local data');
      await tapText(t, 'Delete all');
      expect(days.value, isNull);
    },
  );
  testWidgets(
    'Quick start and end update Home, Calendar and Cycle without a day log',
    (t) async {
      final days = MemoryPeriodStorage(), periods = MemoryPeriodStorage();
      await openApp(t, days: days, periods: periods);
      await tapKey(t, 'home-period-action');
      expect(find.text('Periode starten'), findsWidgets);
      await tapKey(t, 'quick-period-date');
      await t.tap(
        find
            .descendant(
              of: find.byType(DatePickerDialog),
              matching: find.text('17'),
            )
            .last,
      );
      await t.pumpAndSettle();
      await t.tap(
        find.text(
          MaterialLocalizations.of(
            t.element(find.byType(DatePickerDialog)),
          ).okButtonLabel,
        ),
      );
      await t.pumpAndSettle();
      await tapKey(t, 'save-quick-period');
      expect(find.text('Tag 3'), findsOneWidget);
      expect(find.text('Menstruation'), findsOneWidget);
      expect(days.value, isNull);
      expect(
        (await LocalPeriodRepository(periods).load()).single.isOngoing,
        isTrue,
      );
      await tapKey(t, 'home-period-action');
      expect(
        find.text('Welcher war dein letzter Blutungstag?'),
        findsOneWidget,
      );
      await tapKey(t, 'quick-period-date');
      await t.tap(
        find
            .descendant(
              of: find.byType(DatePickerDialog),
              matching: find.text('18'),
            )
            .last,
      );
      await t.pumpAndSettle();
      await t.tap(
        find.text(
          MaterialLocalizations.of(
            t.element(find.byType(DatePickerDialog)),
          ).okButtonLabel,
        ),
      );
      await t.pumpAndSettle();
      await tapKey(t, 'save-quick-period');
      expect(find.text('Deine Periode'), findsNothing);
      expect(
        (await LocalPeriodRepository(periods).load()).single.end,
        today.addDays(-1),
      );
      expect(days.value, isNull);
      await go(t, 'Cycle');
      expect(find.textContaining('17.10.2026'), findsOneWidget);
      await go(t, 'Calendar');
      await tapKey(t, 'calendar-2026-10-18');
      expect(find.text('Period recorded'), findsOneWidget);
      expect(find.text('No day entry yet.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('calendar-period-action')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Wellbeing edits and deletion preserve old bleeding; separate bleeding editor preserves symptoms',
    (t) async {
      final days = MemoryPeriodStorage();
      await LocalJournalRepository(days).save(
        JournalData(
          entries: [
            DayEntry(
              date: today,
              flow: FlowIntensity.light,
              symptoms: {Symptom.cramps},
            ),
          ],
        ),
      );
      await openApp(t, days: days);
      await openForm(t);
      expect(find.text('Flow'), findsNothing);
      expect(find.byKey(const ValueKey('flow-none')), findsNothing);
      await tapKey(t, 'symptom-fatigue');
      await tapKey(t, 'save-day-entry');
      expect(
        (await LocalJournalRepository(days).load()).entries.single.flow,
        FlowIntensity.light,
      );
      await openForm(t);
      await tapText(t, 'Delete this entry');
      await tapText(t, 'Delete');
      expect(find.text('Tag 1'), findsOneWidget);
      final bleedingOnly = (await LocalJournalRepository(
        days,
      ).load()).entries.single;
      expect(bleedingOnly.flow, FlowIntensity.light);
      expect(bleedingOnly.hasWellbeing, isFalse);
      await openForm(t);
      await tapKey(t, 'symptom-fatigue');
      await tapKey(t, 'save-day-entry');
      await go(t, 'Cycle');
      await tapText(t, 'Edit cycle data');
      await tapText(t, 'Blutungsangabe bearbeiten');
      await tapKey(t, 'bleeding-none');
      await tapKey(t, 'save-bleeding');
      expect(
        (await LocalJournalRepository(days).load()).entries.single.flow,
        FlowIntensity.none,
      );
      expect(
        (await LocalJournalRepository(days).load()).entries.single.symptoms,
        {Symptom.fatigue},
      );
    },
  );

  testWidgets('Period history from Home opens the selected calendar month', (
    t,
  ) async {
    final periods = MemoryPeriodStorage(), days = MemoryPeriodStorage();
    await openApp(
      t,
      periods: periods,
      days: days,
      currentDay: CalendarDate(2026, 10, 1),
    );
    await tapKey(t, 'date-2026-09-30');
    await tapKey(t, 'home-period-action');
    await tapText(t, 'Periodenverlauf öffnen');
    expect(find.text('September 2026'), findsWidgets);
    expect(
      find.byKey(const ValueKey('calendar-view-selector')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('calendar-2026-09-30')), findsOneWidget);
    expect(find.text('Deine Perioden'), findsNothing);
    expect(periods.value, isNull);
    expect(days.value, isNull);
  });

  testWidgets(
    'Period history inside Calendar returns to its month; advanced editing stays reachable',
    (t) async {
      await openApp(t);
      await go(t, 'Calendar');
      await tapKey(t, 'calendar-2026-10-19');
      await tapKey(t, 'calendar-period-action');
      await tapText(t, 'Periodenverlauf öffnen');
      expect(find.byKey(const ValueKey('calendar-2026-10-19')), findsOneWidget);
      expect(find.text('Deine Perioden'), findsNothing);
      await go(t, 'Cycle');
      await tapText(t, 'Edit cycle data');
      expect(find.text('Deine Perioden'), findsOneWidget);
    },
  );

  testWidgets('Quick entry cancel and failed save never create a period', (
    t,
  ) async {
    final periods = MemoryPeriodStorage();
    await openApp(t, periods: periods);
    await tapKey(t, 'home-period-action');
    await tapText(t, 'Abbrechen');
    expect(periods.value, isNull);
    await tapKey(t, 'home-period-action');
    periods.failWrite = true;
    await tapKey(t, 'save-quick-period');
    expect(find.textContaining('Deine Eingabe bleibt hier'), findsOneWidget);
    expect(periods.value, isNull);
    periods.failWrite = false;
    await tapKey(t, 'save-quick-period');
    expect(find.text('Tag 1'), findsOneWidget);
  });

  testWidgets(
    'A saved no-bleeding day can be corrected separately in history',
    (t) async {
      final days = MemoryPeriodStorage();
      await LocalJournalRepository(days).save(
        JournalData(
          entries: [DayEntry(date: today, flow: FlowIntensity.none)],
        ),
      );
      await openApp(t, days: days);
      await go(t, 'Cycle');
      await tapText(t, 'Edit cycle data');
      await tapText(t, 'Blutungsangaben prüfen');
      await tapKey(t, 'edit-bleeding-2026-10-19');
      await tapKey(t, 'bleeding-unset');
      await tapKey(t, 'save-bleeding');
      expect((await LocalJournalRepository(days).load()).entries, isEmpty);
    },
  );

  testWidgets('Quick period sheet fits phone and desktop with larger text', (
    t,
  ) async {
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    for (final size in [
      const Size(320, 568),
      const Size(412, 917),
      const Size(1440, 1000),
    ]) {
      t.view.physicalSize = size;
      await openApp(t);
      await tapKey(t, 'home-period-action');
      expect(
        find.text('An welchem Tag hat deine Periode begonnen?'),
        findsOneWidget,
      );
      await tapText(t, 'Abbrechen');
      expect(t.takeException(), isNull, reason: '$size');
    }
  });

  testWidgets(
    'A symptom-only log is visible in the circle without claiming a period',
    (t) async {
      final days = MemoryPeriodStorage();
      await openApp(t, days: days);
      await openForm(t);
      await tapKey(t, 'symptom-cramps');
      await tapKey(t, 'mood-good');
      await tapKey(t, 'save-day-entry');
      expect(find.text('Log gespeichert'), findsOneWidget);
      expect(find.text('Deine Periode'), findsNothing);
      expect(find.textContaining('Log: Cramps'), findsOneWidget);
      await tapKey(t, 'period-status-ring');
      expect(find.text('Dein Tageseintrag'), findsOneWidget);
      expect(find.text('Cramps · Mood: Good'), findsOneWidget);
    },
  );
  testWidgets(
    'Stored log and period failures show an unavailable ring instead of a false zero',
    (t) async {
      final days = MemoryPeriodStorage()..failRead = true;
      await openApp(t, days: days);
      expect(find.text('Nicht verfügbar'), findsOneWidget);
      expect(find.text('Kein Eintrag'), findsNothing);
      days.failRead = false;
      await tapKey(t, 'period-status-ring');
      expect(find.text('Kein Eintrag'), findsOneWidget);
    },
  );
  testWidgets('All seven designs fit small phones and desktop windows', (
    t,
  ) async {
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    t.view.devicePixelRatio = 1;
    for (final size in [
      const Size(320, 568),
      const Size(412, 917),
      const Size(900, 700),
      const Size(1440, 1000),
    ]) {
      t.view.physicalSize = size;
      await openApp(t);
      for (final label in ['Calendar', 'For you', 'Cycle']) {
        await go(t, label);
        expect(t.takeException(), isNull, reason: '$label $size');
      }
      await tapKey(t, 'home-log-button');
      expect(t.takeException(), isNull);
      await tapText(t, 'Continue');
      expect(t.takeException(), isNull);
      await tapKey(t, 'symptom-cramps');
      await tapKey(t, 'save-day-entry');
      expect(t.takeException(), isNull);
      await go(t, 'For you');
      await tapKey(t, 'recommendation-Stretching');
      expect(
        find.textContaining('not based on a detected cycle phase'),
        findsOneWidget,
      );
      await tapText(t, 'Close');
      expect(t.takeException(), isNull);
    }
  });
}
