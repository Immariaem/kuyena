import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuyena_tracker/calendar/presentation/calendar_widgets.dart';
import 'package:kuyena_tracker/calendar/presentation/period_days_editor_page.dart';
import 'package:kuyena_tracker/journal/application/day_journal.dart';
import 'package:kuyena_tracker/journal/data/local_journal_repository.dart';
import 'package:kuyena_tracker/journal/domain/day_entry.dart';
import 'package:kuyena_tracker/periods/application/period_day_editor.dart';
import 'package:kuyena_tracker/periods/application/period_diary.dart';
import 'package:kuyena_tracker/periods/data/local_period_repository.dart';
import 'package:kuyena_tracker/periods/domain/calendar_date.dart';
import 'package:kuyena_tracker/periods/domain/period.dart';
import '../app/seven_screens_test.dart'
    show openApp, tapKey, tapText, go, today;
import '../support/memory_period_storage.dart';

CalendarDate d(int n) => CalendarDate(2026, 10, n);
void main() {
  testWidgets(
    'Calendar edit saves consecutive days, updates Home phase, and survives reopening',
    (t) async {
      final days = MemoryPeriodStorage();
      await openApp(t, days: days);
      await go(t, 'Calendar');
      await tapKey(t, 'edit-period-days');
      expect(find.byType(PeriodDaysEditorPage), findsOneWidget);
      await tapKey(t, 'calendar-2026-10-17');
      await tapKey(t, 'calendar-2026-10-18');
      await tapKey(t, 'calendar-2026-10-19');
      expect(days.value, isNull);
      await tapKey(t, 'save-period-days');
      expect(find.byType(PeriodDaysEditorPage), findsNothing);
      final data = await LocalJournalRepository(days).load();
      expect(data.periodDays, {d(17): true, d(18): true, d(19): true});
      await go(t, 'Home');
      expect(find.text('Tag 3'), findsOneWidget);
      expect(find.text('Menstruation'), findsOneWidget);
      await openApp(t, days: days);
      expect(find.text('Tag 3'), findsOneWidget);
    },
  );
  testWidgets(
    'Removing a period day leaves its wellbeing and shows a gap on Calendar and Home',
    (t) async {
      final days = MemoryPeriodStorage(), manual = MemoryPeriodStorage();
      await LocalJournalRepository(days).save(
        JournalData(
          entries: [
            DayEntry(
              date: today,
              symptoms: {Symptom.fatigue},
              energy: 0,
              note: 'keep',
            ),
          ],
          periodDays: {d(17): true, d(18): true, d(19): true},
        ),
      );
      await openApp(t, days: days, periods: manual);
      await go(t, 'Calendar');
      await tapKey(t, 'edit-period-days');
      await tapKey(t, 'calendar-2026-10-19');
      await tapKey(t, 'save-period-days');
      expect(
        find.byKey(const ValueKey('period-band-2026-10-19')),
        findsNothing,
      );
      await tapKey(t, 'calendar-2026-10-19');
      expect(find.text('No period recorded'), findsOneWidget);
      expect(find.textContaining('keep'), findsOneWidget);
      final data = await LocalJournalRepository(days).load();
      expect(data.entryFor(today)!.symptoms, {Symptom.fatigue});
      expect(data.entryFor(today)!.energy, 0);
      await go(t, 'Home');
      expect(find.text('Deine Periode'), findsNothing);
      expect(find.text('Logged symptoms'), findsOneWidget);
    },
  );
  testWidgets(
    'Toggling a draft twice and cancelling never writes; closing dirty draft asks to discard',
    (t) async {
      final days = MemoryPeriodStorage();
      await openApp(t, days: days);
      await go(t, 'Calendar');
      await tapKey(t, 'edit-period-days');
      await tapKey(t, 'calendar-2026-10-17');
      await tapKey(t, 'calendar-2026-10-17');
      final button = find.descendant(
        of: find.byKey(const ValueKey('save-period-days')),
        matching: find.byType(FilledButton),
      );
      expect(t.widget<FilledButton>(button).onPressed, isNull);
      await tapText(t, 'Abbrechen');
      expect(find.byType(PeriodDaysEditorPage), findsNothing);
      expect(days.value, isNull);
      await tapKey(t, 'edit-period-days');
      await tapKey(t, 'calendar-2026-10-17');
      await tapText(t, 'Abbrechen');
      expect(find.text('Änderungen verwerfen?'), findsOneWidget);
      await tapText(t, 'Weiter bearbeiten');
      expect(
        find.byKey(const ValueKey('period-band-2026-10-17')),
        findsOneWidget,
      );
      await tapText(t, 'Abbrechen');
      await tapText(t, 'Verwerfen');
      expect(days.value, isNull);
    },
  );
  testWidgets(
    'Failed save retains selected days for retry and future dates cannot be marked',
    (t) async {
      final days = MemoryPeriodStorage();
      await openApp(t, days: days);
      await go(t, 'Calendar');
      await tapKey(t, 'edit-period-days');
      await tapKey(t, 'calendar-2026-10-20');
      expect(
        find.byKey(const ValueKey('period-band-2026-10-20')),
        findsNothing,
      );
      await tapKey(t, 'calendar-2026-10-18');
      days.failWrite = true;
      await tapKey(t, 'save-period-days');
      expect(find.textContaining('Deine Auswahl bleibt hier'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('period-band-2026-10-18')),
        findsOneWidget,
      );
      expect(days.value, isNull);
      days.failWrite = false;
      await tapKey(t, 'save-period-days');
      expect(find.byType(PeriodDaysEditorPage), findsNothing);
      expect(
        (await LocalJournalRepository(days).load()).periodDays[d(18)],
        isTrue,
      );
    },
  );
  testWidgets(
    'Red bands connect neighbouring cells, with rounded ends at gaps and week boundaries',
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 350,
              child: MonthGrid(
                month: DateTime(2026, 10),
                today: today,
                onSelect: (_) {},
                periodDays: {d(14), d(15), d(16), d(18), d(19), d(21)},
              ),
            ),
          ),
        ),
      );
      Finder band(int n) => find.byKey(ValueKey('period-band-${d(n).iso}'));
      BorderRadius radius(int n) =>
          (t.widget<Container>(band(n)).decoration! as BoxDecoration)
                  .borderRadius!
              as BorderRadius;
      expect(t.getRect(band(14)).right, t.getRect(band(15)).left);
      expect(t.getRect(band(15)).right, t.getRect(band(16)).left);
      expect(radius(14).topLeft, const Radius.circular(20));
      expect(radius(14).topRight, Radius.zero);
      expect(radius(15), BorderRadius.zero);
      expect(radius(16).topRight, const Radius.circular(20));
      expect(radius(18).topRight, const Radius.circular(20));
      expect(radius(19).topLeft, const Radius.circular(20));
      expect(radius(21), BorderRadius.circular(20));
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Calendar corrections keep Cycle duration accurate and the advanced history consistent',
    (t) async {
      final days = MemoryPeriodStorage(), manual = MemoryPeriodStorage();
      await LocalPeriodRepository(
        manual,
      ).save([Period(id: 'old', start: d(15), end: d(19))]);
      await LocalJournalRepository(
        days,
      ).save(JournalData(periodDays: {d(17): false}));
      await openApp(t, days: days, periods: manual);
      await go(t, 'Cycle');
      expect(find.text('4 d'), findsOneWidget);
      await tapText(t, 'Edit cycle data');
      expect(find.text('Im Kalender bearbeiten'), findsOneWidget);
      await tapText(t, 'Im Kalender bearbeiten');
      expect(find.byType(PeriodDaysEditorPage), findsOneWidget);
      expect(
        find.byKey(const ValueKey('period-band-2026-10-17')),
        findsNothing,
      );
    },
  );
  testWidgets(
    'Export includes calendar corrections even without day logs; clear removes them',
    (t) async {
      final days = MemoryPeriodStorage();
      await LocalJournalRepository(
        days,
      ).save(JournalData(periodDays: {d(17): true, d(18): false}));
      await openApp(t, days: days);
      await go(t, 'Cycle');
      await tapText(t, 'Export data');
      final raw = t.widget<SelectableText>(find.byType(SelectableText)).data!;
      final exported = jsonDecode(raw) as Map<String, dynamic>;
      expect(exported['version'], 2);
      expect(exported['dayEntries'], isEmpty);
      expect(exported['periodDays'], [
        {'date': '2026-10-17', 'period': true},
        {'date': '2026-10-18', 'period': false},
      ]);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      await tapText(t, 'Delete all local data');
      await tapText(t, 'Cancel');
      expect(days.value, isNotNull);
      await tapText(t, 'Delete all local data');
      await tapText(t, 'Delete all');
      expect(days.value, isNull);
    },
  );
  testWidgets(
    'A draft survives a month switch and saves both months together',
    (t) async {
      final days = MemoryPeriodStorage();
      await openApp(t, days: days);
      await go(t, 'Calendar');
      await tapKey(t, 'edit-period-days');
      await tapKey(t, 'calendar-2026-10-01');
      await t.tap(find.byTooltip('Previous month'));
      await t.pumpAndSettle();
      await tapKey(t, 'calendar-2026-09-30');
      await t.tap(find.byTooltip('Next month'));
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('period-band-2026-10-01')),
        findsOneWidget,
      );
      await tapKey(t, 'save-period-days');
      final data = await LocalJournalRepository(days).load();
      expect(data.periodDays, {CalendarDate(2026, 9, 30): true, d(1): true});
    },
  );
  testWidgets(
    'A stale draft cannot overwrite changed period dates and can reload safely',
    (t) async {
      final days = MemoryPeriodStorage(), manual = MemoryPeriodStorage();
      await openApp(t, days: days, periods: manual);
      await go(t, 'Calendar');
      await tapKey(t, 'edit-period-days');
      await tapKey(t, 'calendar-2026-10-12');
      await LocalPeriodRepository(
        manual,
      ).save([Period(id: 'new', start: d(17), end: d(19))]);
      await tapKey(t, 'save-period-days');
      expect(find.textContaining('inzwischen geändert'), findsOneWidget);
      expect(days.value, isNull);
      await tapText(t, 'Neu laden');
      await tapText(t, 'Weiter bearbeiten');
      expect(
        find.byKey(const ValueKey('period-band-2026-10-12')),
        findsOneWidget,
      );
      await tapText(t, 'Neu laden');
      await tapText(t, 'Verwerfen');
      expect(
        find.byKey(const ValueKey('period-band-2026-10-12')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('period-band-2026-10-17')),
        findsOneWidget,
      );
      expect(days.value, isNull);
    },
  );

  testWidgets(
    'Removed legacy-only day has no contradictory flow or empty Log label on Home',
    (t) async {
      final days = MemoryPeriodStorage();
      await LocalJournalRepository(days).save(
        JournalData(
          entries: [DayEntry(date: today, flow: FlowIntensity.light)],
          periodDays: {today: false},
        ),
      );
      await openApp(t, days: days);
      expect(find.text('Keine Periode'), findsOneWidget);
      expect(find.byKey(const ValueKey('ring-log-summary')), findsNothing);
      await tapKey(t, 'period-status-ring');
      expect(find.textContaining('kein Periodentag markiert'), findsOneWidget);
    },
  );

  for (final width in [320.0, 412.0, 1024.0, 1440.0]) {
    testWidgets('Period editing fits width $width and supports larger text', (
      t,
    ) async {
      t.view.physicalSize = Size(width, 850);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final days = MemoryPeriodStorage();
      final editor = PeriodDayEditor(
        diary: PeriodDiary(
          repository: LocalPeriodRepository(MemoryPeriodStorage()),
          clock: () => today.value,
        ),
        journal: DayJournal(
          repository: LocalJournalRepository(days),
          clock: () => today.value,
        ),
      );
      await t.pumpWidget(
        MaterialApp(
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(
              c,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: PeriodDaysEditorPage(editor: editor, initialDate: today),
        ),
      );
      await t.pumpAndSettle();
      await tapKey(t, 'calendar-2026-10-17');
      expect(t.takeException(), isNull);
      final save = t.getRect(find.byKey(const ValueKey('save-period-days')));
      expect(save.bottom, lessThanOrEqualTo(850));
      expect(save.left, greaterThanOrEqualTo(0));
      expect(save.right, lessThanOrEqualTo(width));
    });
  }
}
