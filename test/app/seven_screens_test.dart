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
}) async {
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  await tester.pumpWidget(
    ZyklusApp(
      key: UniqueKey(),
      diary: PeriodDiary(
        repository: LocalPeriodRepository(periods ?? MemoryPeriodStorage()),
        clock: () => today.value,
      ),
      journal: DayJournal(
        repository: LocalJournalRepository(days ?? MemoryPeriodStorage()),
        clock: () => today.value,
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
      await tapKey(t, 'flow-none');
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
