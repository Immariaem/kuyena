import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuyena_tracker/calendar/presentation/calendar_page.dart';
import 'package:kuyena_tracker/calendar/presentation/calendar_widgets.dart';
import 'package:kuyena_tracker/home/presentation/home_design.dart';
import 'package:kuyena_tracker/journal/application/day_journal.dart';
import 'package:kuyena_tracker/journal/data/local_journal_repository.dart';
import 'package:kuyena_tracker/periods/application/period_diary.dart';
import 'package:kuyena_tracker/periods/data/local_period_repository.dart';
import 'package:kuyena_tracker/periods/domain/calendar_date.dart';
import 'package:kuyena_tracker/periods/domain/period.dart';
import '../support/memory_period_storage.dart';

CalendarDate d(int n) => CalendarDate(2026, 10, n);
void main() {
  testWidgets(
    'Calendar information stays optional and usable on small and wide screens without data',
    (t) async {
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetPhysicalSize);
      for (final size in [
        const Size(320, 568),
        const Size(412, 917),
        const Size(900, 900),
        const Size(1440, 1000),
      ]) {
        t.view.physicalSize = size;
        await t.pumpWidget(
          MaterialApp(
            key: UniqueKey(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: CalendarPage(
              key: UniqueKey(),
              diary: PeriodDiary(
                repository: LocalPeriodRepository(MemoryPeriodStorage()),
                clock: () => d(8).value,
              ),
              journal: DayJournal(
                repository: LocalJournalRepository(MemoryPeriodStorage()),
                clock: () => d(8).value,
              ),
              onSelect: (_) {},
              onLog: (_) {},
              onHistory: () {},
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(find.byKey(const ValueKey('calendar-forecast')), findsNothing);
        expect(find.text('≈ geschätzt · Heute im weißen Kreis'), findsNothing);
        expect(
          find.byType(CircularProgressIndicator),
          findsNothing,
          reason: 'loaded at $size',
        );
        expect(
          find.textContaining('Could not load'),
          findsNothing,
          reason: 'loaded at $size',
        );
        expect(
          t
              .widget<IconButton>(find.byKey(const ValueKey('calendar-info')))
              .onPressed,
          isNotNull,
          reason: 'enabled at $size',
        );
        await t.tap(find.byKey(const ValueKey('calendar-info')));
        await t.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('calendar-info-sheet')),
          findsOneWidget,
        );
        expect(find.textContaining('Schätzungen erscheinen'), findsOneWidget);
        expect(t.takeException(), isNull, reason: 'info layout at $size');
        await t.tap(find.byKey(const ValueKey('close-calendar-info')));
        await t.pumpAndSettle();
        expect(find.byKey(const ValueKey('calendar-info-sheet')), findsNothing);
      }
    },
  );

  testWidgets(
    'Predicted period forms a connected band; every today marker is a white circle',
    (t) async {
      Future<void> open(CalendarDate today) async {
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 350,
                child: MonthGrid(
                  month: DateTime(2026, 10),
                  today: today,
                  onSelect: (_) {},
                  periodDays: {d(3)},
                  expectedPeriodDays: {d(14), d(15), d(16)},
                  ovulationDays: {d(20), d(21)},
                  fertileDays: {d(19), d(20), d(21)},
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
      }

      await open(d(15));
      Finder band(int n) =>
          find.byKey(ValueKey('estimated-period-${d(n).iso}'));
      expect(t.getRect(band(14)).right, t.getRect(band(15)).left);
      expect(t.getRect(band(15)).right, t.getRect(band(16)).left);
      final predicted =
          t.widget<Container>(band(15)).decoration! as BoxDecoration;
      expect(predicted.color, HomeDesign.predictedPeriod);
      expect(predicted.borderRadius, BorderRadius.zero);
      for (final n in [3, 10, 15, 19, 20]) {
        await open(d(n));
        final marker = t.widget<Container>(
          find.byKey(ValueKey('calendar-today-${d(n).iso}')),
        );
        final style = marker.decoration! as BoxDecoration;
        expect(style.shape, BoxShape.circle);
        expect(style.color, Colors.white);
      }
      final ov =
          t
                  .widget<Container>(
                    find.byKey(
                      const ValueKey('estimated-ovulation-2026-10-20'),
                    ),
                  )
                  .decoration!
              as BoxDecoration;
      final fertile =
          t
                  .widget<Container>(
                    find.byKey(const ValueKey('estimated-fertile-2026-10-19')),
                  )
                  .decoration!
              as BoxDecoration;
      expect(ov.color, HomeDesign.ovulationPink);
      expect(fertile.color, HomeDesign.pink);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Future days within the predicted period open estimates without creating recorded days',
    (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(412, 1100);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetPhysicalSize);
      final storage = MemoryPeriodStorage(), logs = MemoryPeriodStorage();
      final repo = LocalPeriodRepository(storage);
      await repo.save([Period(id: 'one', start: d(1), end: d(5))]);
      final before = storage.value;
      await t.pumpWidget(
        MaterialApp(
          home: CalendarPage(
            diary: PeriodDiary(repository: repo, clock: () => d(20).value),
            journal: DayJournal(
              repository: LocalJournalRepository(logs),
              clock: () => d(20).value,
            ),
            initialDate: CalendarDate(2026, 11, 2),
            initialCycleLength: 30,
            onSelect: (_) {},
            onLog: (_) {},
            onHistory: () {},
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('estimated-period-2026-11-04')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('period-band-2026-11-02')),
        findsNothing,
      );
      await t.tap(find.byKey(const ValueKey('calendar-2026-11-02')));
      await t.pumpAndSettle();
      expect(find.textContaining('Geschätzte Periode'), findsOneWidget);
      expect(find.text('No period recorded'), findsOneWidget);
      expect(storage.value, before);
      expect(logs.value, isNull);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'Calendar shares personal forecast, marks future window, and never stores it',
    (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(412, 1100);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetPhysicalSize);
      final manual = MemoryPeriodStorage(), logs = MemoryPeriodStorage();
      final repo = LocalPeriodRepository(manual);
      await repo.save([Period(id: '1', start: d(1), end: d(5))]);
      final before = manual.value;
      await t.pumpWidget(
        MaterialApp(
          home: CalendarPage(
            diary: PeriodDiary(repository: repo, clock: () => d(8).value),
            journal: DayJournal(
              repository: LocalJournalRepository(logs),
              clock: () => d(8).value,
            ),
            initialCycleLength: 30,
            onSelect: (_) {},
            onLog: (_) {},
            onHistory: () {},
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('calendar-forecast')), findsNothing);
      expect(find.text('Möglicherweise fruchtbar ≈'), findsNothing);
      expect(
        t.getRect(find.byKey(const ValueKey('calendar-2026-10-15'))).bottom,
        lessThan(720),
      );
      await t.tap(find.byKey(const ValueKey('calendar-info')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('calendar-info-sheet')), findsOneWidget);
      expect(
        find.text('Nächste Periode ≈ 31.10.2026 – 04.11.2026'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Nicht zur Verhütung geeignet'),
        findsOneWidget,
      );
      await t.tap(find.byKey(const ValueKey('close-calendar-info')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('calendar-forecast')), findsNothing);

      expect(
        find.byKey(const ValueKey('estimated-ovulation-2026-10-15')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('estimated-ovulation-2026-10-21')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('estimated-period-2026-10-31')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('period-band-2026-10-15')),
        findsNothing,
      );
      await t.tap(find.byKey(const ValueKey('calendar-2026-10-15')));
      await t.pumpAndSettle();
      expect(
        find.textContaining('Geschätztes Eisprungfenster'),
        findsOneWidget,
      );
      expect(find.text('No period recorded'), findsOneWidget);
      expect(manual.value, before);
      expect(logs.value, isNull);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Recorded red days override estimates; editing and picker hide forecast colours',
    (t) async {
      Future<void> open({bool editing = false, bool picker = false}) async {
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 350,
                child: MonthGrid(
                  month: DateTime(2026, 10),
                  today: d(15),
                  onSelect: (_) {},
                  periodDays: {d(16)},
                  ovulationDays: {d(15), d(16), d(17)},
                  expectedPeriodDays: {d(18)},
                  periodEditing: editing,
                  picker: picker,
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
      }

      await open();
      final band = t.widget<Container>(
        find.byKey(const ValueKey('period-band-2026-10-16')),
      );
      expect((band.decoration! as BoxDecoration).color, HomeDesign.red);
      expect(
        find.byKey(const ValueKey('estimated-ovulation-2026-10-16')),
        findsNothing,
      );
      final pinkToday = t.widget<Container>(
        find.byKey(const ValueKey('estimated-ovulation-2026-10-15')),
      );
      expect((pinkToday.decoration! as BoxDecoration).border, isNull);
      final todayMarker = t.widget<Container>(
        find.byKey(const ValueKey('calendar-today-2026-10-15')),
      );
      expect((todayMarker.decoration! as BoxDecoration).shape, BoxShape.circle);
      expect((todayMarker.decoration! as BoxDecoration).color, Colors.white);

      for (final picker in [false, true]) {
        await open(editing: !picker, picker: picker);
        expect(
          find.byKey(const ValueKey('estimated-ovulation-2026-10-15')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('estimated-period-2026-10-18')),
          findsNothing,
        );
      }
    },
  );
}
