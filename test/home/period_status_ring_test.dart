import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuyena_tracker/home/presentation/home_design.dart';
import 'package:kuyena_tracker/home/presentation/period_status_ring.dart';
import 'package:kuyena_tracker/periods/domain/calendar_date.dart';
import 'package:kuyena_tracker/periods/domain/period.dart';
import 'package:kuyena_tracker/periods/domain/period_day_overview.dart';

PeriodDayOverview overview({bool active = false, bool newCycle = false}) {
  final periods = [
    Period(id: '1', start: CalendarDate(2026, 8, 25)),
    Period(id: '2', start: CalendarDate(2026, 9, 22)),
    Period(
      id: '3',
      start: CalendarDate(2026, 10, 20),
      end: active ? null : CalendarDate(2026, 10, 21),
      isOngoing: active,
    ),
    if (newCycle)
      Period(id: '4', start: CalendarDate(2026, 11, 17), isOngoing: true),
  ];
  return PeriodDayOverview.fromPeriods(
    periods,
    newCycle ? CalendarDate(2026, 11, 17) : CalendarDate(2026, 10, 22),
  );
}

Widget ring(PeriodDayOverview view, {bool reduceMotion = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Scaffold(
      body: PeriodStatusRing(
        scale: 1,
        overview: view,
        isToday: true,
        loading: false,
        loadFailed: false,
        onTap: () {},
      ),
    ),
  ),
);

PeriodRingPainter painter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is CustomPaint &&
                    widget.painter is PeriodRingPainter,
              ),
            )
            .painter!
        as PeriodRingPainter;

void main() {
  testWidgets(
    'Bogen beginnt bei null und baut sich bis zum Zyklusfortschritt auf',
    (tester) async {
      final view = overview();
      await tester.pumpWidget(ring(view));
      expect(painter(tester).progress, 0);
      expect(painter(tester).color, HomeDesign.pink);
      expect(find.text('Noch ca. 26 Tage'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      expect(painter(tester).progress, greaterThan(0));
      expect(painter(tester).progress, lessThan(view.progress!));
      await tester.pumpAndSettle();
      expect(painter(tester).progress, closeTo(2 / 28, 0.00001));
    },
  );

  testWidgets(
    'Aktive Periode ist rot; neuer Beginn setzt den Bogen an den Startpunkt',
    (tester) async {
      await tester.pumpWidget(ring(overview(active: true)));
      await tester.pumpAndSettle();
      expect(painter(tester).color, HomeDesign.red);
      expect(find.text('Tag 3'), findsOneWidget);
      await tester.pumpWidget(ring(overview(active: true, newCycle: true)));
      await tester.pumpAndSettle();
      expect(painter(tester).progress, 0);
      expect(painter(tester).color, HomeDesign.red);
      expect(find.text('Tag 1'), findsOneWidget);
    },
  );

  testWidgets('Reduzierte Bewegung zeigt den Wert ohne Aufbauanimation', (
    tester,
  ) async {
    final view = overview();
    await tester.pumpWidget(ring(view, reduceMotion: true));
    await tester.pumpAndSettle();
    expect(painter(tester).progress, closeTo(view.progress!, 0.00001));
  });
}
