import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuyena_tracker/calendar/presentation/period_days_editor_page.dart';
import 'package:kuyena_tracker/calendar/presentation/period_day_drag_selection.dart';
import 'package:kuyena_tracker/journal/application/day_journal.dart';
import 'package:kuyena_tracker/journal/data/local_journal_repository.dart';
import 'package:kuyena_tracker/journal/domain/day_entry.dart';
import 'package:kuyena_tracker/periods/application/period_day_editor.dart';
import 'package:kuyena_tracker/periods/application/period_diary.dart';
import 'package:kuyena_tracker/periods/data/local_period_repository.dart';
import 'package:kuyena_tracker/periods/domain/calendar_date.dart';
import '../app/seven_screens_test.dart' show tapKey, openApp, go;
import '../support/memory_period_storage.dart';

CalendarDate d(int day) => CalendarDate(2026, 10, day);
Finder day(int n) => find.byKey(ValueKey('calendar-${d(n).iso}'));
Finder band(int n) => find.byKey(ValueKey('period-band-${d(n).iso}'));
FilledButton saveButton(WidgetTester t) => t.widget<FilledButton>(
  find.descendant(
    of: find.byKey(const ValueKey('save-period-days')),
    matching: find.byType(FilledButton),
  ),
);
Future<MemoryPeriodStorage> openEditor(
  WidgetTester t, {
  Map<CalendarDate, bool> marks = const {},
}) async {
  final storage = MemoryPeriodStorage();
  if (marks.isNotEmpty) {
    await LocalJournalRepository(storage).save(JournalData(periodDays: marks));
  }
  final editor = PeriodDayEditor(
    diary: PeriodDiary(
      repository: LocalPeriodRepository(MemoryPeriodStorage()),
      clock: () => d(29).value,
    ),
    journal: DayJournal(
      repository: LocalJournalRepository(storage),
      clock: () => d(29).value,
    ),
  );
  await t.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    PeriodDaysEditorPage(editor: editor, initialDate: d(29)),
              ),
            ),
            child: const Text('Open editor'),
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  await t.tap(find.text('Open editor'));
  await t.pumpAndSettle();
  return storage;
}

Future<TestGesture> beginMouse(WidgetTester t, int n) async {
  await t.ensureVisible(day(n));
  await t.pumpAndSettle();
  return t.startGesture(t.getCenter(day(n)), kind: PointerDeviceKind.mouse);
}

Future<void> move(WidgetTester t, TestGesture gesture, int n) async {
  await gesture.moveTo(t.getCenter(day(n)));
  await t.pump();
}

void main() {
  testWidgets(
    'Mouse drag fills skipped dates, waits for release and writes only on Save',
    (t) async {
      final storage = await openEditor(t);
      final gesture = await beginMouse(t, 10);
      await move(t, gesture, 15);
      for (var n = 10; n <= 15; n++) {
        expect(band(n), findsOneWidget);
      }
      expect(storage.value, isNull);
      expect(saveButton(t).onPressed, isNull);
      await gesture.up();
      await t.pumpAndSettle();
      expect(saveButton(t).onPressed, isNotNull);
      await tapKey(t, 'save-period-days');
      expect((await LocalJournalRepository(storage).load()).periodDays, {
        for (var n = 10; n <= 15; n++) d(n): true,
      });
    },
  );
  testWidgets(
    'Starting on red removes the whole range instead of toggling mixed days',
    (t) async {
      final marks = {for (var n = 10; n <= 15; n++) d(n): true};
      await openEditor(t, marks: marks);
      final gesture = await beginMouse(t, 12);
      await move(t, gesture, 14);
      await gesture.up();
      await t.pumpAndSettle();
      for (final n in [10, 11, 15]) {
        expect(band(n), findsOneWidget);
      }
      for (final n in [12, 13, 14]) {
        expect(band(n), findsNothing);
      }
    },
  );
  testWidgets(
    'Backtracking contracts the current range and preserves all earlier draft edits',
    (t) async {
      await openEditor(t, marks: {d(14): true});
      await tapKey(t, 'calendar-2026-10-20');
      final gesture = await beginMouse(t, 10);
      await move(t, gesture, 15);
      await move(t, gesture, 12);
      await gesture.up();
      await t.pumpAndSettle();
      for (final n in [10, 11, 12, 14, 20]) {
        expect(band(n), findsOneWidget);
      }
      for (final n in [13, 15]) {
        expect(band(n), findsNothing);
      }
    },
  );
  testWidgets(
    'Reverse and week-spanning drags select calendar order without unwanted extra dates',
    (t) async {
      await openEditor(t);
      var gesture = await beginMouse(t, 15);
      await move(t, gesture, 11);
      await gesture.up();
      await t.pumpAndSettle();
      for (var n = 11; n <= 15; n++) {
        expect(band(n), findsOneWidget);
      }
      expect(band(10), findsNothing);
      expect(band(16), findsNothing);
      gesture = await beginMouse(t, 18);
      await move(t, gesture, 20);
      await gesture.up();
      await t.pumpAndSettle();
      for (final n in [18, 19, 20]) {
        expect(band(n), findsOneWidget);
      }
      expect(band(17), findsNothing);
      expect(band(21), findsNothing);
    },
  );
  testWidgets(
    'Touch hold then drag selects once without a second tap on release',
    (t) async {
      await openEditor(t);
      final gesture = await t.startGesture(t.getCenter(day(10)));
      await t.pump(const Duration(milliseconds: 300));
      await move(t, gesture, 15);
      for (var n = 10; n <= 15; n++) {
        expect(band(n), findsOneWidget);
      }
      await gesture.up();
      await t.pumpAndSettle();
      for (var n = 10; n <= 15; n++) {
        expect(band(n), findsOneWidget);
      }
      expect(find.text('Saturday, 10 October 2026'), findsNothing);
    },
  );
  testWidgets(
    'Gesture cancellation rolls back only this drag, keeping previous draft edits',
    (t) async {
      await openEditor(t);
      await tapKey(t, 'calendar-2026-10-20');
      final gesture = await t.startGesture(t.getCenter(day(10)));
      await t.pump(const Duration(milliseconds: 300));
      await move(t, gesture, 15);
      await gesture.cancel();
      await t.pumpAndSettle();
      for (var n = 10; n <= 15; n++) {
        expect(band(n), findsNothing);
      }
      expect(band(20), findsOneWidget);
    },
  );
  testWidgets(
    'Cancelled mouse drag restores the prior draft as touch cancellation does',
    (t) async {
      await openEditor(t);
      await tapKey(t, 'calendar-2026-10-20');
      final gesture = await beginMouse(t, 10);
      await move(t, gesture, 15);
      await gesture.cancel();
      await t.pumpAndSettle();
      for (var n = 10; n <= 15; n++) {
        expect(band(n), findsNothing);
      }
      expect(band(20), findsOneWidget);
    },
  );
  testWidgets(
    'Removing a range then pulling back restores previously red days outside it',
    (t) async {
      await openEditor(t, marks: {for (var n = 10; n <= 15; n++) d(n): true});
      final gesture = await beginMouse(t, 11);
      await move(t, gesture, 15);
      await move(t, gesture, 13);
      await gesture.up();
      await t.pumpAndSettle();
      for (final n in [10, 14, 15]) {
        expect(band(n), findsOneWidget);
      }
      for (final n in [11, 12, 13]) {
        expect(band(n), findsNothing);
      }
    },
  );
  testWidgets(
    'Dragging toward future dates stops at today; starting in the future does nothing',
    (t) async {
      await openEditor(t);
      var gesture = await beginMouse(t, 27);
      await move(t, gesture, 31);
      await gesture.up();
      await t.pumpAndSettle();
      for (final n in [27, 28, 29]) {
        expect(band(n), findsOneWidget);
      }
      for (final n in [30, 31]) {
        expect(band(n), findsNothing);
      }
      gesture = await beginMouse(t, 30);
      await move(t, gesture, 24);
      await gesture.up();
      await t.pumpAndSettle();
      expect(band(24), findsNothing);
      expect(band(25), findsNothing);
    },
  );
  testWidgets(
    'Dragging from a blank leading cell does not select calendar dates',
    (t) async {
      await openEditor(t);
      final grid = t.getRect(find.byType(PeriodDayDragSelection));
      final gesture = await t.startGesture(
        Offset(grid.left + grid.width / 14, grid.top + 22),
        kind: PointerDeviceKind.mouse,
      );
      await move(t, gesture, 5);
      await gesture.up();
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('period-band-2026-10-05')),
        findsNothing,
      );
      expect(saveButton(t).onPressed, isNull);
    },
  );
  testWidgets(
    'A quick vertical touch swipe scrolls without selecting or changing the draft',
    (t) async {
      t.view.physicalSize = const Size(348, 540);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final storage = await openEditor(t);
      final scrollable = find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byType(Scrollable),
      );
      final state = t.state<ScrollableState>(scrollable);
      final before = state.position.pixels;
      final rect = t.getRect(find.byType(PeriodDayDragSelection));
      final viewport = t.getRect(find.byType(SingleChildScrollView));
      final start = Offset(rect.center.dx, viewport.center.dy);
      final gesture = await t.startGesture(start);
      await gesture.moveBy(const Offset(0, -65));
      await t.pump(const Duration(milliseconds: 16));
      await gesture.up();
      await t.pumpAndSettle();
      expect(state.position.pixels, greaterThan(before));
      expect(storage.value, isNull);
      expect(saveButton(t).onPressed, isNull);
    },
  );
  testWidgets(
    'Normal Calendar taps still open day details and do not enable drag editing',
    (t) async {
      await openApp(t, currentDay: d(29));
      await go(t, 'Calendar');
      expect(find.byType(PeriodDayDragSelection), findsNothing);
      await tapKey(t, 'calendar-2026-10-15');
      expect(find.text('No period recorded'), findsOneWidget);
    },
  );
}
